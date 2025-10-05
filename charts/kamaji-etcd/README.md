# kamaji-etcd

![Version: 0.14.0](https://img.shields.io/badge/Version-0.14.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.5.17](https://img.shields.io/badge/AppVersion-3.5.17-informational?style=flat-square)

Helm chart for deploying a multi-tenant `etcd` cluster.

[Kamaji](https://github.com/clastix/kamaji) turns any Kubernetes cluster into an _admin cluster_ to orchestrate other Kubernetes clusters called _tenant clusters_.
The Control Plane of a _tenant cluster_ is made of regular pods running in a namespace of the _admin cluster_ instead of a dedicated set of Virtual Machines.
This solution makes running control planes at scale cheaper and easier to deploy and operate.

As of any Kubernetes cluster, a _tenant cluster_ needs a datastore where to save the state and be able to retrieve data.
This chart provides a multi-tenant `etcd` as datastore for Kamaji as well as a standalone multi-tenant `etcd` cluster.

## Install kamaji-etcd

To install the Chart with the release name `kamaji-etcd`:

        helm repo add clastix https://clastix.github.io/charts
        helm repo update
        helm install kamaji-etcd clastix/kamaji-etcd -n kamaji-etcd --create-namespace

Show the status:

        helm status kamaji-etcd -n kamaji-etcd

Upgrade the Chart

        helm upgrade kamaji-etcd -n kamaji-etcd clastix/kamaji-etcd

Uninstall the Chart

        helm uninstall kamaji-etcd -n kamaji-etcd

## Customize the installation

There are two methods for specifying overrides of values during Chart installation: `--values` and `--set`.

The `--values` option is the preferred method because it allows you to keep your overrides in a YAML file, rather than specifying them all on the command line.
Create a copy of the YAML file `values.yaml` and add your overrides to it.

Specify your overrides file when you install the Chart:

        helm upgrade kamaji-etcd --install --namespace kamaji-etcd --create-namespacekamaji-etcd --values myvalues.yaml

The values in your overrides file `myvalues.yaml` will override their counterparts in the Chart's values.yaml file.
Any values in `values.yaml` that weren't overridden will keep their defaults.

If you only need to make minor customizations, you can specify them on the command line by using the `--set` option. For example:

        helm upgrade kamaji-etcd --install --namespace kamaji-etcd --create-namespace kamaji-etcd --set replicas=5

Here the values you can override:

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Kubernetes affinity rules to apply to etcd pods |
| alerts.annotations | object | `{}` | Assign additional Annotations |
| alerts.enabled | bool | `false` | Enable alerts for Alertmanager |
| alerts.labels | object | `{}` | Assign additional labels according to Prometheus' Alerts matching labels |
| alerts.namespace | string | `""` | Install the Alerts into a different Namespace, as the monitoring stack one (default: the release one) |
| alerts.rules | list | `[]` | The rules for alerts |
| autoCompactionMode | string | `"periodic"` | Interpret 'auto-compaction-retention' one of: periodic|revision. Use 'periodic' for duration based retention, 'revision' for revision number based retention. |
| autoCompactionRetention | string | `"5m"` | Auto compaction retention length. 0 means disable auto compaction. |
| certManager.ca.create | bool | `true` |  |
| certManager.ca.nameOverride | string | `""` |  |
| certManager.ca.validity | string | `"87600h"` | CertManager etcd CA validity |
| certManager.clientCert.create | bool | `true` |  |
| certManager.clientCert.nameOverride | string | `""` |  |
| certManager.enabled | bool | `false` | Enable CertManager for etcd certificates |
| certManager.issuerRef | object | `{}` | CertManager Issuer to use for the etcd certificates |
| certManager.peerCert.additionalDnsNames | list | `[]` |  |
| certManager.peerCert.create | bool | `true` |  |
| certManager.peerCert.nameOverride | string | `""` |  |
| certManager.serverCert.additionalDnsNames | list | `[]` |  |
| certManager.serverCert.create | bool | `true` |  |
| certManager.serverCert.nameOverride | string | `""` |  |
| clientPort | int | `2379` | The client request port. |
| clusterDomain | string | `"cluster.local"` | Domain of the Kubernetes cluster. |
| datastore.annotations | object | `{}` | Assign additional Annotations to the datastore |
| datastore.enabled | bool | `true` | Create a datastore custom resource for Kamaji |
| datastore.headless | bool | `true` | Expose the headless service endpoints in the datastore. Set to false to expose with regular service. |
| datastore.name | string | `""` | Name of Kamaji datastore, set to fully qualified etcd name when null or not provided |
| extraArgs | list | `[]` | A list of extra arguments to add to the etcd default ones |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` | Pull policy to use |
| image.repository | string | `"quay.io/coreos/etcd"` | Install image from specific repo  |
| image.tag | string | `""` | Install image with specific tag, overwrite the tag in the chart |
| imagePullSecrets | list | `[]` |  |
| jobs.affinity | object | `{}` | Kubernetes affinity rules to apply to ancillary jobs |
| jobs.cfssl | object | `{"image":"cfssl/cfssl","tag":""}` | addional images to use for ancillary jobs |
| jobs.etcd.image | string | `"quay.io/coreos/etcd"` |  |
| jobs.etcd.pullPolicy | string | `"IfNotPresent"` |  |
| jobs.etcd.tag | string | `"v3.5.6"` |  |
| jobs.kubectl.image | string | `"clastix/kubectl"` |  |
| jobs.kubectl.tag | string | `""` |  |
| jobs.nodeSelector | object | `{"kubernetes.io/os":"linux"}` | Kubernetes node selector rules for ancillary jobs |
| jobs.tolerations | list | `[]` | Kubernetes node taints that the ancillary jobs would tolerate |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/livez","port":2381,"scheme":"HTTP"},"initialDelaySeconds":10,"periodSeconds":10,"timeoutSeconds":15}` | The livenessProbe for the etcd container |
| metricsPort | int | `2381` | The port where etcd exposes metrics. |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{"kubernetes.io/os":"linux"}` | Kubernetes node selector rules to schedule etcd |
| peerApiPort | int | `2380` | The peer API port which servers are listening to. |
| persistentVolumeClaim.accessModes | list | `["ReadWriteOnce"]` | The Access Mode to storage |
| persistentVolumeClaim.customAnnotations | object | `{}` | The custom annotations to add to the PVC |
| persistentVolumeClaim.size | string | `"8Gi"` | The size of persistent storage for etcd data  |
| persistentVolumeClaim.storageClassName | string | `""` | A specific storage class |
| podAnnotations | object | `{}` | Annotations to add to all etcd pods |
| podLabels | object | `{"application":"kamaji-etcd"}` | Labels to add to all etcd pods |
| priorityClassName | string | `"system-cluster-critical"` | The priorityClassName to apply to etcd |
| quotaBackendBytes | string | `"8589934592"` | Raise alarms when backend size exceeds the given quota. It will put the cluster into a maintenance mode which only accepts key reads and deletes.  |
| replicas | int | `3` | Size of the etcd cluster |
| resources | object | `{"limits":{},"requests":{}}` | Resources assigned to the etcd containers |
| securityContext | object | `{"allowPrivilegeEscalation":false}` | The securityContext to apply to etcd |
| selfSignedCertificates.enabled | bool | `true` | Enables the generation of self-signed certificates for etcd using the cfssl, and kubectl jobs. |
| serviceAccount | object | `{"create":true,"name":""}` | Install an etcd with enabled multi-tenancy |
| serviceAccount.create | bool | `true` | Create a ServiceAccount, required to install and provision the etcd backing storage (default: true) |
| serviceAccount.name | string | `""` | Define the ServiceAccount name to use during the setup and provision of the etcd backing storage (default: "") |
| serviceMonitor.annotations | object | `{}` | Assign additional Annotations |
| serviceMonitor.enabled | bool | `false` | Enable ServiceMonitor for Prometheus |
| serviceMonitor.endpoint.interval | string | `"15s"` | Set the scrape interval for the endpoint of the serviceMonitor |
| serviceMonitor.endpoint.metricRelabelings | list | `[]` | Set metricRelabelings for the endpoint of the serviceMonitor |
| serviceMonitor.endpoint.relabelings | list | `[]` | Set relabelings for the endpoint of the serviceMonitor |
| serviceMonitor.endpoint.scrapeTimeout | string | `""` | Set the scrape timeout for the endpoint of the serviceMonitor |
| serviceMonitor.labels | object | `{"release":"kube-prometheus-stack"}` | Assign additional labels according to Prometheus' serviceMonitorSelector matching labels. By default, it uses the kube-prometheus-stack one. |
| serviceMonitor.matchLabels | object | `{}` | Change matching labels. By default, it uses client service labels. |
| serviceMonitor.namespace | string | `""` | Install the ServiceMonitor into a different namespace than release one. |
| serviceMonitor.serviceAccount | object | `{"name":"kube-prometheus-stack-prometheus","namespace":"monitoring-system"}` | ServiceAccount for scraping metrics from etcd. By defult, it uses the kube-prometheus-stack one. |
| serviceMonitor.serviceAccount.name | string | `"kube-prometheus-stack-prometheus"` | ServiceAccount name |
| serviceMonitor.serviceAccount.namespace | string | `"monitoring-system"` | ServiceAccount namespace |
| serviceMonitor.targetLabels | list | `[]` | Set targetLabels for the serviceMonitor |
| snapshotCount | string | `"10000"` | Number of committed transactions to trigger a snapshot to disk. |
| tolerations | list | `[]` | Kubernetes node taints that the etcd pods would tolerate |
| topologySpreadConstraints | list | `[]` | Kubernetes topology spread constraints to apply to etcd pods |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Adriano Pezzuto | <adriano@clastix.io> | <https://clastix.io> |
| Dario Tranchitella | <dario@clastix.io> | <https://clastix.io> |

## Source Code

* <https://github.com/clastix/kamaji-etcd>
