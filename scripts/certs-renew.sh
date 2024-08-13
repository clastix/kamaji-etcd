#!/bin/bash

# Enable debugging, exit on errors, and ensure the script fails if any command in a pipeline fails
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
set -eu -o pipefail

# Default values for the parameters
ETCD_NAME="kamaji-etcd"
ETCD_SERVICE="kamaji-etcd"
ETCD_NAMESPACE="kamaji-system"

# Parse script parameters
while getopts "e:s:n:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    \? ) echo "Usage: ./certs-renew.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] "
         exit 1 ;;
  esac
done

# Function to create the Role
create_role() {
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
  name: ${ETCD_NAME}-gen-certs-role
  namespace: ${ETCD_NAMESPACE}
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - get
      - patch
      - delete
    resourceNames:
      - ${ETCD_NAME}-certs
      - ${ETCD_NAME}-root-client-certs
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - create
  - apiGroups:
      - apps
    resources:
      - statefulsets
    verbs:
      - get
      - list
      - watch
      - patch
    resourceNames:
      - ${ETCD_NAME}
EOF
}

# Function to create the RoleBinding
create_role_binding() {
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ETCD_NAME}-gen-certs-rolebinding
  namespace: ${ETCD_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${ETCD_NAME}-gen-certs-role
subjects:
  - kind: ServiceAccount
    name: ${ETCD_NAME}
    namespace: ${ETCD_NAMESPACE}
EOF
}

# Function to delete the Role
delete_role() {
  kubectl delete role ${ETCD_NAME}-gen-certs-role -n ${ETCD_NAMESPACE}
}

# Function to delete the RoleBinding
delete_role_binding() {
  kubectl delete rolebinding ${ETCD_NAME}-gen-certs-rolebinding -n ${ETCD_NAMESPACE}
}

# Function to generate the k8s job to renew the certificates
generate_renew_job() {
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: "${ETCD_NAME}-certs-renew"
  namespace: "${ETCD_NAMESPACE}"
spec:
  ttlSecondsAfterFinished: 60
  template:
    metadata:
      name: "${ETCD_NAME}"
    spec:
      serviceAccountName: "${ETCD_NAME}"
      restartPolicy: Never
      initContainers:
        - name: cfssl
          image: cfssl/cfssl:1.6.1
          command:
            - bash
            - -c
            - |-
              cfssl gencert -initca /csr/ca-csr.json | cfssljson -bare /certs/ca &&
              mv /certs/ca.pem /certs/ca.crt && mv /certs/ca-key.pem /certs/ca.key &&
              cfssl gencert -ca=/certs/ca.crt -ca-key=/certs/ca.key -config=/csr/config.json -profile=peer-authentication /csr/peer-csr.json | cfssljson -bare /certs/peer &&
              cfssl gencert -ca=/certs/ca.crt -ca-key=/certs/ca.key -config=/csr/config.json -profile=peer-authentication /csr/server-csr.json | cfssljson -bare /certs/server &&
              cfssl gencert -ca=/certs/ca.crt -ca-key=/certs/ca.key -config=/csr/config.json -profile=client-authentication /csr/root-client-csr.json | cfssljson -bare /certs/root-client
          volumeMounts:
            - mountPath: /certs
              name: certs
            - mountPath: /csr
              name: csr
      containers:
        - name: kubectl
          image: clastix/kubectl:v1.25
          command:
            - sh
            - -c
            - |-
              kubectl create secret generic "${ETCD_NAME}-certs" --from-file=/certs/ca.crt --from-file=/certs/ca.key --from-file=/certs/peer-key.pem --from-file=/certs/peer.pem --from-file=/certs/server-key.pem --from-file=/certs/server.pem --dry-run=client -o yaml | kubectl apply -f - &&
              kubectl create secret tls "${ETCD_NAME}-root-client-certs" --key=/certs/root-client-key.pem --cert=/certs/root-client.pem --dry-run=client -o yaml | kubectl apply -f - &&
              kubectl rollout restart sts/"${ETCD_NAME}" &&
              kubectl rollout status sts/"${ETCD_NAME}" --timeout=300s
          volumeMounts:
            - mountPath: /certs
              name: certs
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      volumes:
        - name: csr
          configMap:
            name: "${ETCD_NAME}-csr"
        - name: certs
          emptyDir: {}
EOF
}

# Function to wait for the job to complete
wait_for_job_completion() {
  kubectl wait --for=condition=complete --timeout=600s job/${ETCD_NAME}-certs-renew -n ${ETCD_NAMESPACE}
}

# Helper function to print the expiration date of a certificate
print_certificate_expiration() {
  local secret_name=$1
  local certificate=$2
  local description=$3

  echo "$description: "
  expiration_date=$(kubectl get secret $secret_name -n $ETCD_NAMESPACE -o json | jq -r ".data[\"$certificate\"]" | base64 --decode | openssl x509 -noout -enddate)
  echo "$expiration_date"

}

# Function to check certificates expiration date
check_certificates() {
  echo "${ETCD_NAME}-certs"
  print_certificate_expiration "${ETCD_NAME}-certs" "ca.crt" "Certification Authority Certificate valid"
  print_certificate_expiration "${ETCD_NAME}-certs" "peer.pem" "etcd peer certificate valid"
  print_certificate_expiration "${ETCD_NAME}-certs" "server.pem" "etcd server certificate valid"

  echo "${ETCD_NAME}-root-client-certs"
  print_certificate_expiration "${ETCD_NAME}-root-client-certs" "tls.crt" "etcd root client certificate valid"
}

# Main script to renew certs
main() {

  # Check secrets before generating new certificates
 check_certificates

  # Create the Role and RoleBinding
  create_role
  create_role_binding

  # Generate and apply the k8s job to renew the certificates
  generate_renew_job

  # Wait for the job to complete
  wait_for_job_completion

  # Check secrets after generating new certificates
  check_certificates

  # Delete the Role and RoleBinding
  delete_role
  delete_role_binding
}

main