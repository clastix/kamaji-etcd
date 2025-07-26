# Take a backup

The `backup.sh` script is designed to create a job for taking snapshot of `etcd` instance. The script generates Kubernetes Job manifests and applies them to the specified namespace.

## Overview
The script performs the following steps:

1. Creates a Kubernetes Job manifests from one of the `etcd` members.
2. The job takes a snapshot of the `etcd` member and uploads it to a s3-like storage.

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
./backup.sh [-e etcd_name] [-s etcd_client_service] [-n etcd_namespace]
```

### Parameters

- `-e etcd_name`: Name of the etcd StatefulSet (default: `kamaji-etcd`)
- `-s etcd_client_service`: Name of the etcd client service (default: `kamaji-etcd-client`)
- `-n etcd_namespace`: Namespace of the etcd StatefulSet (default: `kamaji-system`)

### Example

To run the script with custom parameters:

```bash
./backup.sh -e kamaji-etcd -s kamaji-etcd-client -n kamaji-system
```

This will create a Kubernetes Job manifest with the specified parameters and apply it to the cluster. The job will take a snapshot of the `etcd` member and upload it to the specified S3-like storage.

### Notes

- Ensure you have access a s3-like storage and the necessary secret `backup-storage-secret` is configured in Kubernetes.
- The script uses `kubectl` commands, so ensure you have the necessary permissions to perform these operations.

### Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```

## Schedule recurring backups
To schedule recurring backups with CronJobs, use the `schedule.sh` script. The script generates Kubernetes CronJob manifests and applies them to the specified namespace.

### Usage
To run the script, use the following command:

``` bash
./schedule.sh [-e etcd_name] [-s etcd_client_service] [-n etcd_namespace] [-j schedule]
``` 

### Parameters

- `-e etcd_name`: Name of the etcd StatefulSet (default: `kamaji-etcd`)
- `-s etcd_client_service`: Name of the etcd client service (default: `kamaji-etcd-client`)
- `-n etcd_namespace`: Namespace of the etcd StatefulSet (default: `kamaji-system`)
- `-j schedule`: Cron schedule for the backup job (default: `"0 0 * * *"`, which means daily at midnight)

### Example
To run the script with custom parameters:

```bash
./schedule.sh -e kamaji-etcd -s kamaji-etcd-client -n kamaji-system -j "14 9 * * 1-5"
```
This will create a Kubernetes CronJob manifest with the specified parameters and apply it to the cluster. The CronJob will take a snapshot of the `etcd` member and upload it to the specified S3-like storage according to the defined schedule.

### Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```