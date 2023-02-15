#!/bin/bash

if [ "${DEBUG}" = 1 ]; then
    set -x
fi

echo "Checking old certificates expiration date and fingerprint"
./check.sh 2> /dev/null

# Generate the k8s job to renew the certificates
cat > ${ETCD_NAMESPACE}-${ETCD_NAME}-certs-renew.yaml <<EOF

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

# Run the job to renew the etcd certificates
kubectl -n ${ETCD_NAMESPACE} apply -f ${ETCD_NAMESPACE}-${ETCD_NAME}-certs-renew.yaml &&
sleep 60s

echo "Checking new certificates expiration date and fingerprint"
./check.sh 2> /dev/null
