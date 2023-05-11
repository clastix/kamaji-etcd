# Certificates Renewal Scripts

This script is a simple way to renew the certificates of a `kamaji-etcd` datastore.

It performs the following steps:

1. Check the expiration date and fingerprint of the old certificates
2. Generates a kubernetes job to create certificates through `cfssl`
3. Patches existing secrets with new certificates
4. Reset `etcd` pods and recreates `datastore-certs` secret

> *WARNING*: during the operation, the tenant control plane won't be reachable for a solid minute

## Requirements

- `kamaji-etcd` charts version > 0.2.4
- `bash`
- `jq`
- `openssl`
- `kubectl`

## Procedure

Once you set proper env variables according to your specific setup

```bash
# kamaji-etcd namespace
export ETCD_NAMESPACE=solar-energy-lab
# kamaji-etcd sts name
export ETCD_NAME=solar-energy-etcd
```

run:

```bash
./scripts/certs-renew.sh
```

finally, the script will provide the new certificates dates and fingerprint;

> _NOTE:_ tenant control plane pods are gonna fail with `Error 3/4` but them will auto-heal in about a minute.

## Debug mode

At the beginning of the script, the following line sets the script to run in debug mode if the environment variable `DEBUG` is set to `1`:

``` bash
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
```
