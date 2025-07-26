#!/bin/bash

# Script to create an etcd client pod for inspecting the etcd cluster

# Default values
ETCD_NAME="kamaji-etcd"
ETCD_SERVICE="kamaji-etcd-client"
ETCD_NAMESPACE="kamaji-system"

# Parse script parameters
while getopts "e:s:n:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    \? ) echo "Usage: $0 [-e etcd_name] [-s etcd_clent_service] [-n etcd_namespace]"
         exit 1 ;;
  esac
done

CLIENT_POD_NAME="etcd-client"

# Create the etcd client pod manifest
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${CLIENT_POD_NAME}
  namespace: ${ETCD_NAMESPACE}
spec:
  containers:
  - name: etcd-client
    image: quay.io/coreos/etcd:v3.5.6
    command:
    - sh
    - -c
    - |
      echo "etcd client pod is ready. You can now exec into this pod and run etcdctl commands."
      echo ""
      echo "Example commands:"
      echo "  etcdctl member list -w table"
      echo "  etcdctl endpoint status -w table"
      echo "  etcdctl endpoint health -w table"
      echo "  etcdctl get / --prefix --keys-only"
      echo ""
      echo "Endpoints: \${ENDPOINTS}"
      echo ""
      # Keep the pod running
      while true; do sleep 3600; done
    env:
    - name: ENDPOINTS
      value: "https://${ETCD_SERVICE}.${ETCD_NAMESPACE}.svc.cluster.local:2379"
    - name: ETCDCTL_ENDPOINTS
      value: "https://${ETCD_SERVICE}.${ETCD_NAMESPACE}.svc.cluster.local:2379"
    - name: ETCDCTL_CACERT
      value: /opt/certs/ca/ca.crt
    - name: ETCDCTL_CERT
      value: /opt/certs/root-client-certs/tls.crt
    - name: ETCDCTL_KEY
      value: /opt/certs/root-client-certs/tls.key
    volumeMounts:
    - mountPath: /opt/certs/root-client-certs
      name: root-client-certs
      readOnly: true
    - mountPath: /opt/certs/ca
      name: certs
      readOnly: true
  restartPolicy: Always
  serviceAccountName: ${ETCD_NAME}
  volumes:
  - name: root-client-certs
    secret:
      secretName: ${ETCD_NAME}-root-client-certs
  - name: certs
    secret:
      secretName: ${ETCD_NAME}-certs
EOF

echo ""
echo "etcd client pod created. To use it:"
echo ""
echo "  kubectl exec -it ${CLIENT_POD_NAME} -n ${ETCD_NAMESPACE} -- bash"
echo ""
echo "Then run etcdctl commands like:"
echo "  etcdctl member list"
echo "  etcdctl endpoint status --write-out=table"
echo "  etcdctl endpoint health"
echo ""
