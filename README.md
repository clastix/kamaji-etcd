# Kamaji etcd
A set of tools to deploy and operate a multi-tenant `etcd` datastore for [Kamaji](https://github.com/clastix/kamaji) control-plane.

## Background
Kamaji turns any Kubernetes cluster into an “admin cluster” to orchestrate other Kubernetes clusters called “tenant clusters”. The Control Plane of a “tenant cluster” is made of regular pods running in a namespace of the “admin cluster” instead of a dedicated set of Virtual Machines. This solution makes running control planes at scale cheaper and easier to deploy and operate.

As of any Kubernetes cluster, a “tenant cluster” needs a datastore where to save the state and be able to retrieve data. Kamaji provides multiple options: a multi-tenant `etcd` as well as _MySQL_, and _PostgreSQL_, thanks to the [kine](https://github.com/k3s-io/kine) integration.

A multi-tenant deployment for `etcd` is not common practice. However, `etcd` provides simple and robust APIs for creating users and setting up role based access control (RBAC) policies to define which user have access to what key prefix. Please, refer to the project [documentation](https://etcd.io/docs/v3.5/op-guide/authentication/) for more details.


Following sections provide additional procedures to help with a specific setup as it is used into project [Kamaji](https://github.com/clastix/kamaji).

- [Recovery from a snapshot](docs/snapshot-recovery.md)
- [Backup and Restore with Velero](docs/backup-and-restore.md)
- [Rotate Certificates](docs/rotate-certificates.md)
- [Performance and Optimization](docs/performance-and-optimization.md)

## Roadmap

- [x] Install High Available `etcd` cluster as StatefulSet
- [x] Provide data persistence through Persistent Volumes
- [x] Multi-tenancy
- [x] Autocompaction
- [x] Scheduled defragmentation
- [x] Auto generate certificates
- [x] Scheduled snapshots
- [x] Metrics Service Monitors
- [x] Alert rules
- [ ] Grafana dashboard
- [ ] Benchmarking

## Getting started
On the Kamaji's “admin cluster”, install the multi-tenant `etcd` with the provided Helm Chart:

```
helm repo add clastix https://clastix.github.io/charts
helm install kamaji-etcd clastix/kamaji-etcd -n kamaji-etcd --create-namespace
```

The certificates of `etcd`, are stored as secrets into the same namespace:

- `<release_name>-certs` contains CA, peers, and server certificates
- `<release_name>-root-client-certs` contains the user `root` certificates

Make sure the Kamaji controller can access these secrets in their namespaces. 