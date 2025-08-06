#!/bin/bash

# Copyright 2025 Clastix Labs
# SPDX-License-Identifier: Apache-2.0

# Enable debugging, exit on errors, and ensure the script fails if any command in a pipeline fails
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
set -eu -o pipefail

# Default values for the parameters
ETCD_NAME="kamaji-etcd"
ETCD_SERVICE="kamaji-etcd"
ETCD_NAMESPACE="kamaji-system"
SCHEDULE="0 0 * * *"  # Default cron schedule (e.g., daily at midnight)

# Parse script parameters
while getopts "e:s:n:j:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    j ) SCHEDULE=$OPTARG ;;
    \? ) echo "Usage: ./schedule.sh [-e etcd_name] [-s etcd_client_service] [-n etcd_namespace] [-j schedule]"
         exit 1 ;;
  esac
done

# Function to create the CronJob manifest for backing up etcd
create_backup_cronjob() {
  local etcd_name=$1
  local etcd_service=$2
  local etcd_namespace=$3
  local schedule=$4  # Add a parameter for the cron schedule

  cat <<EOF > ${etcd_name}-schedule-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${etcd_name}-schedule-job
  namespace: $etcd_namespace
spec:
  schedule: "$schedule"  # Use the provided schedule
  jobTemplate:
    spec:
      template:
        spec:
          initContainers:
          - name: etcd-client
            image: quay.io/coreos/etcd:v3.5.6
            command:
            - sh
            - -c
            - |
                # Take snapshot of etcd member
                SNAPSHOT=${etcd_name}_\$(date +%Y%m%d%H%M%S).db
                ENDPOINTS=https://${etcd_service}.${etcd_namespace}.svc.cluster.local:2379
                etcdctl --endpoints \${ENDPOINTS} snapshot save /opt/dump/\${SNAPSHOT}
                etcdutl --write-out=table snapshot status /opt/dump/\${SNAPSHOT}
                md5sum /opt/dump/\${SNAPSHOT}
            env:
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
          containers:
          - name: minio-client
            image: minio/mc:RELEASE.2022-11-07T23-47-39Z
            command:
            - sh
            - -c
            - |
              # Set up MinIO client and upload the snapshot
              if \$MC alias set storage \${STORAGE_URL} \${STORAGE_ACCESS_KEY} \${STORAGE_SECRET_KEY} && \$MC ping storage -c 3 -e 3; then
                 \$MC cp /opt/dump/${etcd_name}_*.db storage/\${STORAGE_BUCKET_NAME}/\${STORAGE_BUCKET_FOLDER:+/\${STORAGE_BUCKET_FOLDER}}/;
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
          restartPolicy: OnFailure
          serviceAccountName: ${etcd_name}
          volumes:
          - name: shared-data
            emptyDir: {}
          - name: root-client-certs
            secret:
              secretName: ${etcd_name}-root-client-certs
          - name: certs
            secret:
              secretName: ${etcd_name}-certs
EOF
}

# Main script to backup etcd
main() {
  # Create and apply backup CronJob
  create_backup_cronjob "$ETCD_NAME" "$ETCD_SERVICE" "$ETCD_NAMESPACE" "$SCHEDULE"
  kubectl apply -f $ETCD_NAME-schedule-job.yaml
}

# Execute the main script
main