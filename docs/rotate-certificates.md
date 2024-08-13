# Certificates Renewal Scripts

This guide explains how to use the `certs-renew.sh` script to renew the certificates of a `kamaji-etcd` datastore.

It performs the following steps:

1. Check the expiration date of the old certificates
2. Cretates temporary role and rolebinding to permit the script to access certificates
3. Cretates a kubernetes job to create certificates through `cfssl`
4. Patches existing secrets with new certificates
5. Reset `etcd` pods and recreates `datastore-certs` secret
6. Remove temporary role and rolebinding

> *WARNING*: during the operation, the tenant control plane won't be reachable for a solid minute

## Requirements

- `kamaji-etcd` charts version > 0.2.4
- `bash`
- `jq`
- `openssl`
- `kubectl`

## Usage

To run the script, use the following command:

``` bash
./scripts/certs-renew.sh [-e etcd_name] [-s etcd_service] [-n etcd_namespace]
```

## Parameters

- `-e etcd_name`: The name of the etcd instance (default: `kamaji-etcd`).
- `-s etcd_service`: The name of the etcd service (default: `kamaji-etcd`).
- `-n etcd_namespace`: The namespace where etcd is deployed (default: `kamaji-system`).

For example:

``` bash
./scripts/certs-renew.sh -e my-etcd -s my-etcd-service -n my-namespace
```

## Notes

- Tenant Control Plane pods may fail with `Error 3/4` but will auto-heal in about a minute.
- Ensure you have the necessary permissions to create and delete roles and role bindings in the specified namespace.

## Debug mode
To run the script in debug mode set the environment variable `DEBUG`:

``` bash
export DEBUG=1
```
