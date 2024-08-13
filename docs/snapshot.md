# Take a snapshot

The `backup.sh` script is designed to create and schedule jobs for backing up a kamaji-etcd cluster. The script generates Kubernetes CronJob manifests and applies them to the specified namespace.

## Overview
The script performs the following steps:

1. Creates a Kubernetes CronJob manifests for each `etcd` member (assumes three members).
2. Each job takes a snapshot of the `etcd` member and uploads it to a s3-like storage.


## Prerequisites

- Ensure you have `kubectl` installed and configured to interact with the management cluster.
- It is assumed that the snapshot files will be stored on an S3-like storage.
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
./backup.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] [-j schedule]
```

## Parameters

- `-e etcd_name`: Name of the etcd StatefulSet (default: `kamaji-etcd`)
- `-s etcd_service`: Name of the etcd service (default: `kamaji-etcd`)
- `-n etcd_namespace`: Namespace of the etcd StatefulSet (default: `kamaji-system`)
- `-j schedule`: Cron schedule for the backup job (default: `"0 0 * * *"`, which means daily at midnight)

This example schedules the backup job to run daily at 3 AM:

```bash
./backup.sh -e my-etcd -s my-etcd-service -n my-namespace -j "0 3 * * *"
```


## Notes

- Ensure you have access a s3-like storage and the necessary secret is configured in Kubernetes.
- The script uses `kubectl` commands, so ensure you have the necessary permissions to perform these operations.

## Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```
