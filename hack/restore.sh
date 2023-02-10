#!/bin/bash -eau

# TO DO
# Add switch case for parameters
# Detect kamaji-controller deploy method (deploy/sts)
# Create a bash function for scaling
# Add kamaji tcp scale down/up
# Add helper
# Add nice prints/decoration to better understand what's happening during shell execution
# Improve etcdHealth func to auto check HEALTH column

if [ "${DEBUG}" = 1 ]; then
    set -x
fi

# Parameters
KAMAJI_TCP=$1
ETCD_NAMESPACE=$2
KAMAJI_TCP_SNAP_URL=$3
ETCD_INSTANCE=$4

# Service variables
KAMAJI_PODS_JSON="kubectl get pods -n $ETCD_NAMESPACE -l app.kubernetes.io/instance=$ETCD_INSTANCE -o json"
KAMAJI_TCP_SNAP="snapshot.db"
TMP_FOLDER="/tmp"
ETCD_TMP_FOLDER="$TMP_FOLDER/etcd-restore"
ETCD_DEFAULT_FOLDER="member"
ETCD_SNAPSHOT_FOLDER="snapshot"
ETCD_INITIAL_CLUSTER=""
ETCD_CLIENT_PORT=2379
ETCD_PEER_PORT=2380
ETCD_HTTP_PROTOCOL="https"

ETCD_CONTAINER_NAME=$($KAMAJI_PODS_JSON |\
    jq -j '.items[] | "\(.spec.containers[0].name)\n"' |\
        uniq)

ETCD_RUN_FOLDER=$($KAMAJI_PODS_JSON |\
    jq -j '.items[] | "\(.spec.containers[0].volumeMounts[0].mountPath)\n"' |\
        uniq)

# Retrieve informations about deployed Kamaji Pods
declare -a KAMAJI_PODS=$($KAMAJI_PODS_JSON |\
    jq -j '.items[] | "\(.metadata.name)\n"')

ETCD_PODS_COUNT=$(printf "%s\n" "${KAMAJI_PODS[@]}" |\
    wc -l)

declare -a ETCD_INSTANCE_HOSTIP=$($KAMAJI_PODS_JSON |\
    jq -j '.items[] | "\(.status.hostIP)\n"')

declare -a KAMAJI_TCP_DATASTORE=$($KAMAJI_PODS_JSON |\
    jq -j '.items[] | "\(.spec.volumes[].persistentVolumeClaim.claimName)\n"' |\
        grep -v null)

# Functions
etcdInitialCluster() {
  for POD in ${KAMAJI_PODS[@]}; do
    ETCD_SVC_SUFFIX=$(kubectl exec -it $POD -c $ETCD_CONTAINER_NAME -n $ETCD_NAMESPACE \
      -- /bin/sh -c \
          "getent hosts $ETCD_INSTANCE | awk '{print \$2}' | uniq")
    ETCD_SVC_SUFFIX="${ETCD_SVC_SUFFIX%%[[:cntrl:]]}" # remove dirty characters
    TMP_INITIAL_CLUSTER="$POD=$ETCD_HTTP_PROTOCOL://$POD.$ETCD_SVC_SUFFIX:$ETCD_PEER_PORT"
    ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER,$TMP_INITIAL_CLUSTER"
  done
  ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER:1}" # remove first comma
}

etcdSnapshotDownload() {
  wget -nv $KAMAJI_TCP_SNAP_URL -O $KAMAJI_TCP_SNAP &&\
    md5sum $KAMAJI_TCP_SNAP
}

etcdSnapshotUpload() {
  kubectl cp $KAMAJI_TCP_SNAP $ETCD_NAMESPACE/$POD:$TMP_FOLDER -c $ETCD_CONTAINER_NAME
}

etcdSnapshotRestore() {
  for POD in ${KAMAJI_PODS[@]}; do
    etcdSnapshotUpload

    kubectl exec -it $POD -c $ETCD_CONTAINER_NAME -n $ETCD_NAMESPACE \
      -- /bin/sh -c \
          "cd $TMP_FOLDER
           chown root:root $KAMAJI_TCP_SNAP &&
           etcdutl --write-out=table snapshot status $KAMAJI_TCP_SNAP &&
           mkdir $ETCD_TMP_FOLDER &&
           etcdutl \
              --data-dir $ETCD_TMP_FOLDER \
              --name $POD \
              --initial-cluster $ETCD_INITIAL_CLUSTER \
              --initial-cluster-token kamaji \
              --initial-advertise-peer-urls $ETCD_HTTP_PROTOCOL://$POD.$ETCD_SVC_SUFFIX:$ETCD_PEER_PORT \
              snapshot restore $KAMAJI_TCP_SNAP &&
           cp -pR $ETCD_TMP_FOLDER/$ETCD_DEFAULT_FOLDER $ETCD_RUN_FOLDER/$ETCD_SNAPSHOT_FOLDER"
  done
}

etcdFolderSwitch() {
  for DATA in ${KAMAJI_TCP_DATASTORE[@]}; do
    KAMAJI_PVC_JSON="kubectl get pvc $DATA -n $ETCD_NAMESPACE -o json"
  
    PVC_SCNAME=$($KAMAJI_PVC_JSON |\
      jq -j '.spec.storageClassName')
  
    PVC_VOLUMENAME=$($KAMAJI_PVC_JSON |\
      jq -j '.spec.volumeName')
  
    PVC_NODE=$($KAMAJI_PVC_JSON |\
      jq -j '.metadata.annotations["volume.kubernetes.io/selected-node"]')
 
  cat <<EOF | kubectl apply -f -
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: $DATA-restore-job
    namespace: $ETCD_NAMESPACE
  spec:
    ttlSecondsAfterFinished: 10
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: $DATA-restore
            image: alpine:3.17.0
            command: ["/bin/ash"]
            args: ["-c", "cd $ETCD_TMP_FOLDER && mv $ETCD_DEFAULT_FOLDER $ETCD_DEFAULT_FOLDER-$(date +%Y%m%d%H%M).BAK && mv $ETCD_SNAPSHOT_FOLDER $ETCD_DEFAULT_FOLDER"]
            volumeMounts:
              - mountPath: "$ETCD_TMP_FOLDER"
                name: $DATA-restore-storage
        volumes:
          - name: $DATA-restore-storage
            persistentVolumeClaim:
              claimName: $DATA
        nodeSelector:
          kubernetes.io/hostname: $PVC_NODE
EOF
  done
}

etcdHealth() {
  for POD in ${KAMAJI_PODS[@]}; do
    kubectl exec -it $POD -c $ETCD_CONTAINER_NAME -n $ETCD_NAMESPACE \
      -- /bin/sh -c \
          "
           export ETCDCTL_API=3
           export ETCDCTL_ENDPOINTS=$ETCD_HTTP_PROTOCOL://$POD.$ETCD_SVC_SUFFIX:$ETCD_CLIENT_PORT
           export ETCDCTL_CACERT=/etc/etcd/pki/ca.crt
           export ETCDCTL_CERT=/etc/etcd/pki/server.pem
           export ETCDCTL_KEY=/etc/etcd/pki/server-key.pem

           etcdctl --write-out=table endpoint health
          "
  done
}

# Combine etcd svc strings in order to use the
# ETCD_INITIAL_CLUSTER var during restore step
etcdInitialCluster

# Download desired snapshot from choosen URL locally
etcdSnapshotDownload

# Upload locally downloaded snapshot
# to pods and restore it
etcdSnapshotRestore

# Scale the etcd cluster to 0 so I can manipulate member folders in peace
kubectl scale sts $ETCD_INSTANCE --replicas 0 -n $ETCD_NAMESPACE &&\
  sleep 10

# Let's make sure that etcd is stopped
kubectl get pods -n $ETCD_NAMESPACE -l app.kubernetes.io/instance=$ETCD_INSTANCE

# Create a "shell" pod for every kamaji-etcd PVC in order to
# switch etcd data directories directly from kubectl
etcdFolderSwitch &&\
  sleep 10

# Re-Scale Up the etcd cluster to the original replicas
kubectl scale sts $ETCD_INSTANCE --replicas $ETCD_PODS_COUNT -n $ETCD_NAMESPACE &&\
  sleep 10

# Let's make sure that etcd is Running as expected
etcdHealth
