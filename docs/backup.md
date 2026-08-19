# Take a backup

> **Recommended:** the chart ships a scheduled backup as an opt-in feature.
> Set `backup.enabled=true` (see chart values) to have Helm manage a snapshot
> CronJob that uploads via `rclone`. The `backup.sh` script below remains for
> ad-hoc, one-off backups.

The `backup.sh` script is designed to create a job for taking snapshot of `etcd` instance. The script generates Kubernetes Job manifests and applies them to the specified namespace.

## Overview
The script performs the following steps:

1. Creates a Kubernetes Job manifests from one of the `etcd` members.
2. The job takes a snapshot of the `etcd` member and uploads it to object storage with `rclone`.

## Prerequisites

- Ensure you have `kubectl` installed and configured to interact with the management cluster.
- Object storage reachable by `rclone`. Any [rclone backend](https://rclone.org/overview/) works, including S3-compatible providers, Azure Blob, Backblaze B2 and SFTP.
- A kubernetes secret called `backup-storage-secret` containing the parameters and credentials to access the storage must be created in the same namespace where `kamaji-etcd` is running.

### Creating the Secret

The secret's keys are rclone environment variables, and the whole secret is loaded into
the upload container with `envFrom`. They define an rclone remote named `backup` plus the
destination within it. rclone reads configuration from the environment before its config
file, so every backend and every backend option is reachable without changing the chart
or these scripts.

| Key | Required | Purpose |
|---|---|---|
| `RCLONE_CONFIG_BACKUP_TYPE` | yes | Backend type, e.g. `s3`, `azureblob`, `b2`, `sftp` |
| `RCLONE_CONFIG_BACKUP_<OPTION>` | backend-dependent | Any config option of that backend, uppercased with `_` for `-` |
| `STORAGE_BUCKET_NAME` | yes | Bucket or container name |
| `STORAGE_BUCKET_FOLDER` | no | Sub-path within the bucket |

For an S3-compatible target, the available options are listed under
[rclone's S3 backend](https://rclone.org/s3/); the common ones are `provider`, `endpoint`,
`access_key_id`, `secret_access_key`, `region`, `location_constraint` and
`no_check_bucket`.

MinIO:

```bash
kubectl create secret generic backup-storage-secret \
  --from-literal=RCLONE_CONFIG_BACKUP_TYPE=s3 \
  --from-literal=RCLONE_CONFIG_BACKUP_PROVIDER=Minio \
  --from-literal=RCLONE_CONFIG_BACKUP_ENDPOINT=<storage_url> \
  --from-literal=RCLONE_CONFIG_BACKUP_ACCESS_KEY_ID=<access_key> \
  --from-literal=RCLONE_CONFIG_BACKUP_SECRET_ACCESS_KEY=<access_secret> \
  --from-literal=STORAGE_BUCKET_NAME=<bucket_name> \
  --from-literal=STORAGE_BUCKET_FOLDER=<bucket_folder> \
  -n <etcd_namespace>
```

Hetzner Object Storage:

```bash
kubectl create secret generic backup-storage-secret \
  --from-literal=RCLONE_CONFIG_BACKUP_TYPE=s3 \
  --from-literal=RCLONE_CONFIG_BACKUP_PROVIDER=Hetzner \
  --from-literal=RCLONE_CONFIG_BACKUP_ENDPOINT=https://fsn1.your-objectstorage.com \
  --from-literal=RCLONE_CONFIG_BACKUP_ACCESS_KEY_ID=<access_key> \
  --from-literal=RCLONE_CONFIG_BACKUP_SECRET_ACCESS_KEY=<access_secret> \
  --from-literal=RCLONE_CONFIG_BACKUP_NO_CHECK_BUCKET=true \
  --from-literal=STORAGE_BUCKET_NAME=<bucket_name> \
  --from-literal=STORAGE_BUCKET_FOLDER=<bucket_folder> \
  -n <etcd_namespace>
```

Two things worth knowing before the first run:

- **`PROVIDER` is a case-sensitive enum.** It must match a value from rclone's provider
  list exactly — `Hetzner`, not `hetzner`. An unknown value is not an error: rclone logs
  `s3 provider "..." not known` as a NOTICE and falls back to generic S3 behaviour, which
  usually surfaces later as a confusing failure.
- **The bucket is expected to exist.** Without `NO_CHECK_BUCKET=true`, rclone issues a
  `CreateBucket` call before the first upload. Providers that tie a bucket to a location
  reject that call unless `LOCATION_CONSTRAINT` matches, e.g. Hetzner answers
  `LocationConstraintConflict`. Setting `NO_CHECK_BUCKET=true` skips the check entirely
  and keeps `CreateBucket` off the permissions the access key needs.

### Verifying the secret

The remote definition can be checked without a cluster, using the same environment the
job will see:

```bash
docker run --rm \
  -e RCLONE_CONFIG=/dev/null \
  -e RCLONE_CONFIG_BACKUP_TYPE=s3 \
  -e RCLONE_CONFIG_BACKUP_PROVIDER=Hetzner \
  -e RCLONE_CONFIG_BACKUP_ENDPOINT=https://fsn1.your-objectstorage.com \
  -e RCLONE_CONFIG_BACKUP_ACCESS_KEY_ID=<access_key> \
  -e RCLONE_CONFIG_BACKUP_SECRET_ACCESS_KEY=<access_secret> \
  -e RCLONE_CONFIG_BACKUP_NO_CHECK_BUCKET=true \
  rclone/rclone:1.74.4 ls backup:<bucket_name>
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

This will create a Kubernetes Job manifest with the specified parameters and apply it to the cluster. The job will take a snapshot of the `etcd` member and upload it to the configured object storage.

### Notes

- Ensure you have access to object storage and the necessary secret `backup-storage-secret` is configured in Kubernetes.
- The script uses `kubectl` commands, so ensure you have the necessary permissions to perform these operations.
- The generated Job runs non-root with a read-only root filesystem and all capabilities dropped, so it is admissible under a `restricted` PodSecurity label.

### Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```

## Schedule recurring backups

Recurring backups are a chart feature. Set `backup.enabled=true` and Helm manages the
CronJob, including snapshot retention:

```yaml
backup:
  enabled: true
  schedule: "0 0 * * *"
  storageSecret: backup-storage-secret
  retention:
    mode: count   # none | count | age
    count: 7
```

See the chart's [values documentation](../charts/kamaji-etcd/README.md) for the full set
of options. The CronJob uses the same `backup-storage-secret` contract described above.
