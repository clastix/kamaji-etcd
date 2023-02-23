# Datastore Restore Scripts

## Introduction
This script is a simple way to restore the etcd of a `kamaji-etcd` datastore to a previously backed-up version.

It performs the following steps:

1. Downloads the etcd snapshot specified during script launch
2. Populates the ETCD_INITIAL_CLUSTER variable with a list of the TCP etcd pods
3. Uploads the etcd snapshot to each kamaji-etcd pod
4. Restores the snapshot to each kamaji-etcd pod using the etcdctl command.

*WARNING*:
During the operation, the TCP won't be reachable for a solid minute

## Requirements

- Correctly set `.env` file in the parent folder
- A reachable URL to download the desired etcd-snapshot
- `bash`
- `jq`
- `wget`
- `kubectl`

## Execution

Once you sourced the `.env` file placed in the parent folder

```bash
source ../.env
```

you have to manually scale-down TCP replicas:

```bash
kubectl scale tcp -n ${TENANT_NAMESPACE} ${TENANT_NAME} --replicas=0
```

then, simply execute:

```bash
./restore.sh 'https://mys3publicurl.io/tcp-snapshot.db'
```

finally, the script will provide the health status of the etcd cluster;
in case of a positive outcome, you just need to recreate the client tcp replicas:

```bash
kubectl scale tcp -n ${TENANT_NAMESPACE} ${TENANT_NAME} --replicas=X
```

## Notes

### Debug Mode

At the beginning of the script, the following line sets the script to run in debug mode if the environment variable `DEBUG` is set to `1`:

``` bash
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
```
