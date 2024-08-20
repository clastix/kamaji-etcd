# Defragmenting Data
For dense Kubernetes clusters, `etcd` can suffer from poor performance if the keyspace grows too large and exceeds the space quota. Periodically maintain and defragment `etcd` to free up space in the data store. See details [here](https://etcd.io/docs/v3.5/op-guide/maintenance/).

Monitor Prometheus for `etcd` metrics and defragment it when required, otherwise, `etcd` can raise a cluster-wide alarm that puts the cluster into a maintenance mode accepting only key reads and deletes.

To keep track of defragmentation requirements, monitor these key metrics:

- `etcd_server_quota_backend_bytes`: which is the current quota limit
- `etcd_mvcc_db_total_size_in_use_in_bytes`: which indicates the actual database usage after a history compaction
- `etcd_mvcc_db_total_size_in_bytes`, which shows the database size, including free space waiting for defragmentation

You can also determine whether defragmentation is needed by checking the `etcd` database size in MB that will be freed by defragmentation with the PromQL expression:

- `(etcd_mvcc_db_total_size_in_bytes - etcd_mvcc_db_total_size_in_use_in_bytes)/1024/1024`

Defragmentation is an expensive operation, so it should be executed as infrequently as possible. On the other hand, it's also necessary to make sure any `etcd` member will not exceed the storage quota. The Kubernetes project recommends that when you perform defragmentation, you use a tool such as [etcd-defrag](https://github.com/ahrtr/etcd-defrag).

The `defrag.sh` script is designed to create and schedule jobs for periodically defragment data on a `kamaji-etcd` instance. The script generates Kubernetes CronJob manifests and applies them to the specified namespace. Make sure you set the defragmentation criteria according to your environment needs. 


## Usage
To run the script, use the following command:

```bash
./defrag.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace] [-j schedule]
```

## Parameters

- `-e etcd_name`: Name of the etcd StatefulSet (default: `kamaji-etcd`)
- `-s etcd_service`: Name of the etcd service (default: `kamaji-etcd`)
- `-n etcd_namespace`: Namespace of the etcd StatefulSet (default: `kamaji-system`)
- `-j schedule`: Cron schedule for the defrag job (default: `"0 0 * * *"`, which means daily at midnight)

## Example

To run the script with custom parameters:

```bash
./defrag.sh -e kamaji-etcd -s kamaji-etcd -n kamaji-system -j "14 9 * * 1-5"
```
This will create a Kubernetes CronJob manifest with the specified parameters and apply it to the cluster.

## Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```
