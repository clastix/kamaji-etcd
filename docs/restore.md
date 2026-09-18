# Recover from a snapshot

This guide provides instructions on how to use the `restore.sh` script to restore a `kamaji-etcd` datastore from a snapshot.

## Overview

The script performs the following steps:

1. Scales down the `etcd` StatefulSet to zero replicas.
2. Waits for the `etcd` pods to be deleted.
3. Creates a restore job for each `etcd` member (assumes three members) to restore the data from the snapshot.
4. Waits for each restore job to complete.
5. Scales the `etcd` StatefulSet back to three replicas.

## Requirements

- Ensure you have `kubectl` installed and configured to interact with the management cluster.
- The snapshot should be taken previously with the `backup.sh` script or the chart's backup CronJob. It is assumed that the snapshot file is stored on object storage reachable by `rclone`.
- A kubernetes secret called `backup-storage-secret` containing the parameters and credentials to access the storage must be created in the same namespace where `kamaji-etcd` is running.

### Creating the Secret

The restore job reads the same secret the backup writes with. Its keys are rclone
environment variables defining a remote named `backup`; see
[Take a backup](backup.md#creating-the-secret) for the full contract, the per-provider
examples and how to verify the secret without a cluster.

```bash
kubectl create secret generic backup-storage-secret \
  --from-literal=RCLONE_CONFIG_BACKUP_TYPE=s3 \
  --from-literal=RCLONE_CONFIG_BACKUP_PROVIDER=<provider> \
  --from-literal=RCLONE_CONFIG_BACKUP_ENDPOINT=<storage_url> \
  --from-literal=RCLONE_CONFIG_BACKUP_ACCESS_KEY_ID=<access_key> \
  --from-literal=RCLONE_CONFIG_BACKUP_SECRET_ACCESS_KEY=<access_secret> \
  --from-literal=STORAGE_BUCKET_NAME=<bucket_name> \
  --from-literal=STORAGE_BUCKET_FOLDER=<bucket_folder> \
  -n <etcd_namespace>
```

## Usage

To run the script, use the following command:

```bash
./restore.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] [-f snapshot]
```

### Parameters

- `-e etcd_name`: Name of the etcd StatefulSet (default: `kamaji-etcd`)
- `-s etcd_service`: Name of the etcd headless service (default: `kamaji-etcd`)
- `-n etcd_namespace`: Namespace of the etcd StatefulSet (default: `kamaji-system`)
- `-f snapshot`: Snapshot file to restore from (required)

### Notes

- Ensure that the snapshot file is accessible and the necessary secret `backup-storage-secret` for accessing the storage is configured in the same namespace.
- The script uses `kubectl` commands, so ensure you have the necessary permissions to perform these operations.
- The Kubernetes project recommends you should stop all the control plane components before restoring the etcd datastore. [Here](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#restoring-an-etcd-cluster).
- **Verify the snapshot is reachable before you start.** The script scales the StatefulSet to zero *before* the restore jobs download the snapshot, so a wrong endpoint, a missing object or a bad credential leaves `etcd` stopped with nothing restored. The `docker run ... rclone ls backup:<bucket>` command in [Take a backup](backup.md#verifying-the-secret) confirms both the credentials and the presence of the file.
- The restore Job's `rclone` container runs non-root with a read-only root filesystem and all capabilities dropped. Its `etcd-client` container drops capabilities too but keeps the default UID on purpose: it rewrites the etcd data directory on the PVC, which `etcd` itself owns, and the chart defaults the StatefulSet's `podSecurityContext` to `{}` — that is root. Forcing a UID there would make the restore depend on `fsGroup` re-owning the volume, which not every CSI driver supports. As a consequence the restore Job is **not** admissible under a `restricted` PodSecurity label; making it so requires running `etcd` itself as non-root via the chart's `podSecurityContext`.

### Example:

```bash
./restore.sh -e kamaji-etcd -s kamaji-etcd -n kamaji-system -f snapshot.db
```

> 🚨 Make sure to use the **headless service** name for the `-s` parameter, which is typically the same as the StatefulSet name.

### Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```