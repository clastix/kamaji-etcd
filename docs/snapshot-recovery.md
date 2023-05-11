# Recovery from a snapshot

This script is a simple way to restore a `kamaji-etcd` datastore from a previou taken snapshot.

It performs the following steps:

1. Downloads the `etcd` snapshot specified during script launch.
2. Populates the `ETCD_INITIAL_CLUSTER` variable with a list of the `kamaji-etcd` pods.
3. Uploads the `etcd` snapshot to every `kamaji-etcd` pod.
4. Restores the snapshot to every `kamaji-etcd` pod using the `etcdctl` command.

> *WARNING*: during the operation, the tenant control plane won't be reachable for a solid minute

## Requirements

- `bash`
- `jq`
- `wget`
- `kubectl`

## Procedure

Once you set proper env variables according to your specific setup

```bash
# kamaji-etcd namespace
export ETCD_NAMESPACE=solar-energy-lab
# kamaji-etcd sts name
export ETCD_NAME=solar-energy-etcd
# tenant control plane namespace
export TENANT_NAMESPACE=solar-energy-lab
# tenant control plane name
export TENANT_NAME=solar-energy
```

scale down to zero the tenant control plane pods:

```bash
kubectl scale tcp -n ${TENANT_NAMESPACE} ${TENANT_NAME} --replicas=0
```

run:

```bash
./scripts/snapshot-recovery.sh 'https://mys3publicurl.io/tcp-snapshot.db'
```

The script will provide the health status of the etcd cluster: in case of a positive outcome, scale up the tenant control plane pods to the previous number of replicas:

```bash
kubectl scale tcp -n ${TENANT_NAMESPACE} ${TENANT_NAME} --replicas=X
```

## Debug mode

At the beginning of the script, the following line sets the script to run in debug mode if the environment variable `DEBUG` is set to `1`:

``` bash
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
```
