# Certificates Renewal Scripts

## Introduction
This script is a simple way to renew the certificates of an `kamaji-etcd` datastore.

It performs the following steps:

1. Check the expiration date and fingerprint of the old certificates
2. Generates a k8s job to create certificates through `cfssl`
3. Patches existing secrets with new certificates
4. Reset etcd pods and recreates `datastore-certs` secret

*WARNING*:
During the operation, the TCP won't be reachable for a solid minute

## Requirements

- Correctly set `.env` file in the parent folder
- `kamaji-etcd` charts version > 0.2.4
- `bash`
- `jq`
- `openssl`
- `kubectl`

## Execution

Once you sourced the `.env` file placed in the parent folder

```bash
source ../.env
```

simply execute:

```bash
./renew.sh
```

finally, the script will provide the new certificates dates and fingerprint;
TCP pods are gonna fail with `Error 3/4` but will auto-heal in about a minute.

## Notes

### Debug Mode

At the beginning of the script, the following line sets the script to run in debug mode if the environment variable `DEBUG` is set to `1`:

``` bash
if [ "${DEBUG}" = 1 ]; then
    set -x
fi
```
