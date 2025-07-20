# Monitoring kamaji-etcd

Monitoring `etcd` is critically important for maintaining the health of a Kubernetes cluster. Loss of the `etcd` quorum can lead to cluster failure. Common issues, such as high latency between `etcd` nodes, disk performance problems, or excessive throughput, often lead to availability issues with `etcd`.

The container running `etcd` exposes metrics on the `/metrics` endpoint, which can be monitored for insights:

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

The `etcd` metrics are exposed on port `2381` by default, and can be accessed via the `/metrics` endpoint of kamaji-etcd-client service:

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    prometheus.io/metrics: "true"
  name: kamaji-etcd-client
spec:
  ports:
  - name: client
    port: 2379
    protocol: TCP
    targetPort: 2379
  - name: metrics
    port: 2381
    protocol: TCP
    targetPort: 2381
  selector:
    app.kubernetes.io/instance: kamaji-etcd
```

These metrics can be collected by Prometheus Operator and used for both monitoring and debugging purposes.

## Setting up Prometheus Operator

To begin monitoring `kamaji-etcd`, install the Prometheus Operator stack using Helm:

```sh
helm repo add kube-prometheus-stack https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus kube-prometheus-stack/kube-prometheus-stack \
    --set prometheus.persistence.enabled=true \
    --namespace monitoring-system \
    --create-namespace
```

The `kamaji-etcd` Helm chart includes an optional `ServiceMonitor` for Prometheus Operator, enabling it to scrape `etcd` metrics:

```sh
helm -n kamaji-etcd upgrade kamaji-etcd clastix/kamaji-etcd \
    --set datastore.enabled=true \
    --set datastore.name=default \
    --set fullnameOverride=kamaji-etcd \
    --set serviceMonitor.enabled=true
```

By default such `ServiceMonitor` is installed in the same namespace as the `kamaji-etcd` release. If you want to install it in a different namespace, you can set the `serviceMonitor.namespace` value to the desired namespace.

By default, the `ServiceMonitor` is configured to scrape metrics every 15 seconds. You can adjust this interval by setting the `serviceMonitor.endpoint.interval` value.

By default, the `ServiceMonitor` uses the ServiceAccount `kube-prometheus-stack-prometheus` in the `monitoring-system` namespace to scrape metrics from etcd. If you want to use a different ServiceAccount, you can set the `serviceMonitor.serviceAccount.name` and value `serviceMonitor.serviceAccount.namespace` to the desired values.

## Key Metrics to Monitor

Here’s a summary of important `etcd` metrics that help monitor cluster health. A full list of metrics is available [here](https://etcd.io/docs/v3.5/metrics/etcd-metrics-latest.txt).

> Note: `etcd` metrics are not persisted across restarts. If the process restarts, the metrics will reset.

### Active Instances

To count the number of active `etcd` instances in your cluster:

```sh
count(etcd_cluster_version)
```

### Active Leader

This metric shows whether the `etcd` instances have a leader. To count how many instances have a leader:

```sh
count(etcd_server_has_leader)
```

To check leader changes over the last hour (growing numbers could indicate performance or network issues):

```sh
max(increase(etcd_server_leader_changes_seen_total[60m]))
```

### Raft Consensus Proposals

A Raft consensus proposal represents a request, such as a write request to update cluster state. This metric should increase over time as the cluster commits changes.

Monitor committed proposals across all `etcd` instances to detect potential performance issues:

```sh
etcd_server_proposals_committed_total
```

If pending requests are high over time, this may indicate either heavy load or an inability to commit changes:

```sh
etcd_server_proposals_pending
```

Failures in requests often arise from leader election processes or quorum loss. Count the number of failed proposals in the last hour:

```sh
max(rate(etcd_server_proposals_failed_total[60m]))
```

### Disk Metrics

High disk write latency can signal disk issues and affect `etcd` stability. To monitor disk performance, visualize the time taken to commit 99% of requests:

```sh
histogram_quantile(0.99, sum(rate(etcd_disk_backend_commit_duration_seconds_bucket{job=~"kamaji-etcd"}[5m])) by (le,instance))
```

### Network Metrics

Monitor network latency by measuring the round trip time (RTT) to replicate a request between `etcd` members. High or increasing RTT can signal network issues that may lead to quorum loss:

```sh
histogram_quantile(0.99, sum(rate(etcd_network_peer_round_trip_time_seconds_bucket[5m])) by (le,instance))
```

This value should remain below 50ms (0.050s).

## Visualizing with Grafana

Metrics scraped from `kamaji-etcd` can be visualized with Grafana. Install Grafana and import the dashboard from [here](../monitoring/grafana-dashboard.json).

