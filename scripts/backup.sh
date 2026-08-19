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
ETCD_SERVICE="kamaji-etcd-client"
ETCD_NAMESPACE="kamaji-system"

# Parse script parameters
while getopts "e:s:n:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    \? ) echo "Usage: ./backup.sh [-e etcd_name] [-s etcd_client_service] [-n etcd_namespace]"
         exit 1 ;;
  esac
done

# Function to create the Job manifest for backing up etcd
create_backup_job() {
  local etcd_name=$1
  local etcd_service=$2
  local etcd_namespace=$3

  cat <<EOF > ${etcd_name}-backup-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${etcd_name}-backup-job-$(date +%s)
  namespace: $etcd_namespace
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
            # Take snapshot of etcd using service endpoint
            SNAPSHOT=${etcd_name}_\$(date +%Y%m%d%H%M%S).db
            ENDPOINTS=https://${etcd_service}.${etcd_namespace}.svc.cluster.local:2379
            etcdctl --endpoints \${ENDPOINTS} endpoint status
            etcdctl --endpoints \${ENDPOINTS} snapshot save /opt/dump/\${SNAPSHOT}
            etcdutl snapshot status /opt/dump/\${SNAPSHOT}
            md5sum /opt/dump/\${SNAPSHOT}
        env:
        - name: ETCDCTL_CACERT
          value: /opt/certs/ca/ca.crt
        - name: ETCDCTL_CERT
          value: /opt/certs/root-client-certs/tls.crt
        - name: ETCDCTL_KEY
          value: /opt/certs/root-client-certs/tls.key
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - mountPath: /opt/certs/root-client-certs
          name: root-client-certs
        - mountPath: /opt/certs/ca
          name: certs
        - mountPath: /opt/dump
          name: shared-data
      containers:
      - name: upload
        image: rclone/rclone:1.74.4
        command:
        - sh
        - -c
        - |
          # Upload the snapshot to the remote defined by the secret
          set -e
          : "\${RCLONE_CONFIG_BACKUP_TYPE:?not set - see docs/backup.md for the required secret keys}"
          : "\${STORAGE_BUCKET_NAME:?not set - see docs/backup.md for the required secret keys}"
          DEST="backup:\${STORAGE_BUCKET_NAME}\${STORAGE_BUCKET_FOLDER:+/\${STORAGE_BUCKET_FOLDER}}"
          rclone copy /opt/dump "\${DEST}/" --include "${etcd_name}_*.db"
        envFrom:
        - secretRef:
            name: backup-storage-secret
        env:
        - name: RCLONE_CONFIG
          value: /dev/null
        - name: XDG_CACHE_HOME
          value: /tmp
        - name: TMPDIR
          value: /tmp
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - mountPath: /opt/dump
          name: shared-data
        - mountPath: /tmp
          name: tmp
      restartPolicy: OnFailure
      serviceAccountName: ${etcd_name}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      volumes:
      - name: shared-data
        emptyDir: {}
      - name: tmp
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
  # Create and apply single backup Job
  create_backup_job "$ETCD_NAME" "$ETCD_SERVICE" "$ETCD_NAMESPACE"
  kubectl apply -f $ETCD_NAME-backup-job.yaml
}

# Execute the main script
main
