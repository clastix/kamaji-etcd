# Monitoring kamaji-etcd
Monitoring `etcd` properly is of vital importance for a Kubernetes cluster. If the `etcd` quorum is lost, and the `etcd` consequently cluster fails. Big latencies between the `etcd` nodes, disk performance issues, or high throughput are some of the common root causes of availability problems with `etcd`.

The container running `etcd` exposes metrics on the `/metrics` endpoint: 

```yaml
spec:
  containers:
  - command:
    - etcd
    - --listen-client-urls=https://0.0.0.0:2379
    - --listen-metrics-urls=http://0.0.0.0:2381
    - --listen-peer-urls=https://0.0.0.0:2380
    - --client-cert-auth=true
...
```

These metrics can be scraped with Prometheus and used for monitoring and debugging.

## Prometheus
To start monitoring `kamaji-etcd`, first install a Prometheus stack:

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install kube-prometheus bitnami/kube-prometheus \
    --set prometheus.persistence.enabled=true \
    --namespace monitoring-system \
    --create-namespace
```

The `kamaji-etcd` Helm Chart optionally provides a ServiceMonitor to instrument Prometheus scraping `etcd` metrics:

```sh
helm -n kamaji-etcd upgrade kamaji-etcd clastix/kamaji-etcd \
    --set datastore.enabled=true \
    --set datastore.name=default \
    --set fullnameOverride=default \
    --set serviceMonitor.enabled=true \
    --set serviceMonitor.namespace=monitoring-system
```

## Metrics
Following, you will find a summary of the key `etcd` metrics. These will give you visibility on the health of the cluster. A complete list of `etcd` metrics can be found [here](https://etcd.io/docs/v3.5/metrics/etcd-metrics-latest.txt).

> The `etcd` does not persist its metrics: if the process restarts, the metrics will be reset.

### Active instances
Count how many `etcd` instances are active in your cluster:

```
count(etcd_cluster_version)
```

### Active Leader
This metric indicates whether the `etcd` instances have a leader or not. Count how many have a leader:

```
count(etcd_server_has_leader)
```

Check the leader changes within the last hour. If this number grows over time, it may similarly indicate performance or network problems.

```
max(increase(etcd_server_leader_changes_seen_total[60m]))
```

### Raft Consensus Proposals
A Raft consensus proposal is a request, like a write request to add a new configuration or track a new state. It can be a change in a configuration, like a ConfigMap or any other Kubernetes object. This metric should increase over time, as it indicates the cluster is healthy and committing changes.

It is important to monitor this metric across all the `etcd` instances since a large consistent lag between a member and its leader may indicate the node is unhealthy or having performance issues:

```
etcd_server_proposals_committed_total
```

A high number or pending requests over time may indicate there is a high load or that the `etcd` member cannot commit changes:

```
etcd_server_proposals_pending
```

Failures with requests are basically due to a leader election process or a downtime caused by loss of quorum. Count how many proposals failed within the last hour:

```
max(rate(etcd_server_proposals_failed_total[60m]))
```

### Disk Metrics
High latency in disk writes may indicate disk issues, and may cause a high latency on `etcd` requests or even make the cluster unstable or unavailable. To know if the latency of commits are good enough, get the time latency in which 99% of requests are covered and you visualize it in a graph: 

```
histogram_quantile(0.99, sum(rate(etcd_disk_backend_commit_duration_seconds_bucket{job=~"etcd"}[5m])) by (le,instance))
```

### Network Metrics
Measure the Round Trip Time latency to replicate a request between etcd members. A high latency or latency growing over time may indicate issues in the network, causing serious trouble and even losing quorum.

```
histogram_quantile(0.99, sum(rate(etcd_network_peer_round_trip_time_seconds_bucket[5m])) by (le,instance))
```

This value should not exceed 50ms (0.050s).

## Grafana
Metrics scraped from `kamaji-etcd` can be visualised with Grafana. Install Grafana and upload the dashboard [here](../monitoring/grafana-dashboard.json).
