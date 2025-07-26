# Kamaji etcd
A set of tools to deploy and operate a multi-tenant `etcd` datastore for [Kamaji](https://github.com/clastix/kamaji) control-plane.

## Background
Kamaji turns any Kubernetes cluster into a Management Cluster to orchestrate other Kubernetes clusters called Tenant Clusters. The Control Plane of a tenant cluster is made of regular pods running in a namespace of the Management Cluster instead of a dedicated set of Virtual Machines. This solution makes running control planes at scale cheaper and easier to deploy and operate.

As of any Kubernetes cluster, a Tenant Cluster needs a datastore where to save the state and be able to retrieve data. Kamaji provides multiple options: a multi-tenant `etcd` as well as _MySQL_, and _PostgreSQL_, thanks to the [kine](https://github.com/k3s-io/kine) integration.

A multi-tenant deployment for `etcd` is not common practice. However, `etcd` provides simple and robust APIs for creating users and setting up role based access control (RBAC) policies to define which user have access to what key prefix. However, in Kamaji, you can use multiple `kamaji-etcd` for different tenants. The relationship between tenant clusters and datastore can be many-to-one, one-to-one, depending on the preferencess and use cases. 

## Documentation
Refer to the [etcd documentation](https://etcd.io/docs/v3.5/op-guide). Following sections provide additional procedures to help with a specific setup as it is used into project [Kamaji](https://github.com/clastix/kamaji).

- [Inspecting the Cluster](docs/inspect.md)
- [Monitoring](docs/monitoring.md)
- [Backup](docs/backup.md)
- [Restore](docs/restore.md)
- [Rotate Certificates](docs/rotate-certificates.md)
- [Defragmenting Data](docs/defragmentation.md)
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
- [x] Grafana dashboard
- [ ] Benchmarking

## Getting started
To install the multi-tenant `kamaji-etcd` on the Kamaji Management Cluster using the provided Helm Chart, run the following commands:

```bash
helm repo add clastix https://clastix.github.io/charts
helm repo update
helm install kamaji-etcd clastix/kamaji-etcd -n kamaji-etcd --create-namespace
```

The `etcd` certificates are stored as secrets into the same namespace:

- `<release_name>-certs` contains CA, peers, and server certificates
- `<release_name>-root-client-certs` contains the user `root` certificates

Ensure the Kamaji controller has access to these secrets. 