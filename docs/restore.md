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
- The snapshot should be taken previously with the `backup.sh` script. It is assumed that the snapshot file is stored on an S3-like storage.
- A kubernetes secret called `backup-storage-secret` containing the parameters and credentials to access the storage must be created in the same namespace where `kamaji-etcd` is running.

### Creating the Secret

To create the secret, use the following command:

```bash
kubectl create secret generic backup-storage-secret \
  --from-literal=storage-url=<storage_url> \
  --from-literal=storage-access-key=<access_key> \
  --from-literal=storage-secret-key=<access_secret> \
  --from-literal=storage-bucket-name=<bucket_name> \
  --from-literal=storage-bucket-folder=<bucket_folder> \
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