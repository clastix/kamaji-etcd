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
SNAPSHOT=""  # snapshot file

# Parse script parameters
while getopts "e:s:n:f:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    f ) SNAPSHOT=$OPTARG ;;
    \? ) echo "Usage: ./restore.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] [-f snapshot]"
         exit 1 ;;
  esac
done

# Function to create the job manifest for restoring etcd from a snapshot
create_restore_job() {
  local index=$1
  local etcd_name=$2
  local etcd_service=$3
  local etcd_namespace=$4

  cat <<EOF > ${etcd_name}-restore-job-${index}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${etcd_name}-restore-job-${index}
  namespace: $etcd_namespace
spec:
  template:
    spec:
      initContainers:
      - name: minio-client
        image: minio/mc:RELEASE.2022-11-07T23-47-39Z
        command:
        - sh
        - -c
        - |
          # Set up MinIO client and download the snapshot
          if \$MC alias set storage \${STORAGE_URL} \${STORAGE_ACCESS_KEY} \${STORAGE_SECRET_KEY} && \$MC ping storage -c 3 -e 3; then
             \$MC cp storage/\${STORAGE_BUCKET_NAME}/\${STORAGE_BUCKET_FOLDER}/${SNAPSHOT} /opt/dump;
          else
             exit 1;
          fi
        env:
        - name: STORAGE_URL
          valueFrom:
            secretKeyRef:
              name: backup-storage-secret
              key: storage-url
        - name: STORAGE_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: backup-storage-secret
              key: storage-access-key
        - name: STORAGE_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: backup-storage-secret
              key: storage-secret-key
        - name: STORAGE_BUCKET_NAME
          valueFrom:
            secretKeyRef:
              name: backup-storage-secret
              key: storage-bucket-name
        - name: STORAGE_BUCKET_FOLDER
          valueFrom:
            secretKeyRef:
              name: backup-storage-secret
              key: storage-bucket-folder
        - name: MC
          value: "/usr/bin/mc --config-dir /tmp"
        volumeMounts:
        - mountPath: /opt/dump
          name: shared-data
      containers:
      - name: etcd-client
        image: quay.io/coreos/etcd:v3.5.6
        command:
        - sh
        - -c
        - |
            # Remove existing etcd member data and restore from snapshot
            rm -rf /var/run/etcd/member
            etcdctl snapshot restore /opt/dump/${SNAPSHOT} \
            --data-dir /var/run/etcd \
            --name ${etcd_name}-${index} \
            --initial-cluster ${etcd_name}-0=https://${etcd_name}-0.${etcd_service}.${etcd_namespace}.svc.cluster.local:2380,${etcd_name}-1=https://${etcd_name}-1.${etcd_service}.${etcd_namespace}.svc.cluster.local:2380,${etcd_name}-2=https://${etcd_name}-2.${etcd_service}.${etcd_namespace}.svc.cluster.local:2380 \
            --initial-cluster-token kamaji \
            --initial-advertise-peer-urls https://${etcd_name}-${index}.${etcd_service}.${etcd_namespace}.svc.cluster.local:2380
        env:
        - name: ENDPOINTS
          value: https://localhost:2379
        - name: ETCDCTL_CACERT
          value: /opt/certs/ca/ca.crt
        - name: ETCDCTL_CERT
          value: /opt/certs/root-client-certs/tls.crt
        - name: ETCDCTL_KEY
          value: /opt/certs/root-client-certs/tls.key
        volumeMounts:
        - mountPath: /opt/certs/root-client-certs
          name: root-client-certs
        - mountPath: /opt/certs/ca
          name: certs
        - mountPath: /opt/dump
          name: shared-data
        - mountPath: /var/run/etcd
          name: data 
      restartPolicy: OnFailure
      serviceAccountName: ${etcd_name}
      volumes:
      - name: shared-data
        emptyDir: {}
      - name: data
        persistentVolumeClaim:
          claimName: data-${etcd_name}-${index}
      - name: root-client-certs
        secret:
          secretName: ${etcd_name}-root-client-certs
      - name: certs
        secret:
          secretName: ${etcd_name}-certs
EOF
}

# Function to scale the etcd StatefulSet
scale_etcd() {
  local replicas=$1
  kubectl -n "$ETCD_NAMESPACE" scale sts "$ETCD_NAME" --replicas="$replicas"
}

# Function to wait for the deletion of etcd pods
wait_for_pod_deletion() {
  kubectl wait --for=delete pods -n "$ETCD_NAMESPACE" --selector=app.kubernetes.io/instance="$ETCD_NAME" --timeout=300s
}

# Function to wait for the completion of a restore job
wait_for_job_completion() {
  local index=$1
  kubectl wait --for=condition=complete job/$ETCD_NAME-restore-job-${index} -n "$ETCD_NAMESPACE" --timeout=300s
}

# Main script to restore etcd from a snapshot
main() {

  # Scale down the etcd StatefulSet to zero replicas
  scale_etcd 0
  # Wait for the etcd pods to be deleted
  wait_for_pod_deletion

  # Create and apply restore jobs in parallel
  for i in {0..2}; do
    create_restore_job ${i} "$ETCD_NAME" "$ETCD_SERVICE" "$ETCD_NAMESPACE"
    kubectl apply -f $ETCD_NAME-restore-job-${i}.yaml &
  done

  # Wait for all background jobs to complete
  wait

  # Wait for each restore job to complete
  for i in {0..2}; do
    wait_for_job_completion ${i}
  done

  # Scale the etcd StatefulSet back to three replicas
  scale_etcd 3
}

# Execute the main script
main