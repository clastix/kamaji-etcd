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
SCHEDULE="0 0 * * *"  # every day at midnight

# Parse script parameters
while getopts "e:s:n:j:" opt; do
  case ${opt} in
    e ) ETCD_NAME=$OPTARG ;;
    s ) ETCD_SERVICE=$OPTARG ;;
    n ) ETCD_NAMESPACE=$OPTARG ;;
    j ) SCHEDULE=$OPTARG ;;
    \? ) echo "Usage: ./defrag.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] [-j schedule]"
         exit 1 ;;
  esac
done

# Function to create the CronJob manifest for defrag etcd
create_defrag_cronjob() {
  local etcd_name=$1
  local etcd_service=$2
  local etcd_namespace=$3
  local schedule=$4  # Add a parameter for the cron schedule

  cat <<EOF > ${etcd_name}-defrag-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${etcd_name}-defrag-job
  namespace: $etcd_namespace
spec:
  schedule: "$schedule"  # Use the provided schedule
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: etcd-defrag
            image: ghcr.io/ahrtr/etcd-defrag:v0.15.0 # Please replace the version with the latest version.
            args:
            - --endpoints=https://${etcd_name}-0.${etcd_service}.${etcd_namespace}.svc.cluster.local:2379,https://${etcd_name}-1.${etcd_service}.${etcd_namespace}.svc.cluster.local:2379,https://${etcd_name}-2.${etcd_service}.${etcd_namespace}.svc.cluster.local:2379
            - --cacert=/opt/certs/ca/ca.crt
            - --cert=/opt/certs/root-client-certs/tls.crt
            - --key=/opt/certs/root-client-certs/tls.key
            - --cluster
            - --defrag-rule
            - "dbQuotaUsage > 0.8 || dbSize - dbSizeInUse > 200*1024*1024"
            volumeMounts:
            - mountPath: /opt/certs/root-client-certs
              name: root-client-certs
            - mountPath: /opt/certs/ca
              name: certs
          restartPolicy: OnFailure
          securityContext:
            runAsUser: 0
          volumes:
          - name: root-client-certs
            secret:
              secretName: ${etcd_name}-root-client-certs
          - name: certs
            secret:
              secretName: ${etcd_name}-certs
EOF
}

# Main script to defrag etcd
main() {
  # Create and apply defrag CronJob
    create_defrag_cronjob "$ETCD_NAME" "$ETCD_SERVICE" "$ETCD_NAMESPACE" "$SCHEDULE"
    kubectl apply -f $ETCD_NAME-defrag-job.yaml
}

# Execute the main script
main