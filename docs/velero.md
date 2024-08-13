# Disaster Recovery with Velero

A `kamaji-etcd` is just a regular set of stateful workloads running in the Kamaji Management Cluster. As such, you can take advantage of the same methods that you would use to maintain other stateful workloads.

This guide will assist you in how operate backup and restore a `kamaji-etcd` setup using [Velero](https://tanzu.vmware.com/developer/guides/what-is-velero/).

## Prerequisites

Before proceeding with the next steps, we assume that the following prerequisites are met:

- Velero command line installed on your workstation
- Velero installed on the Management Cluster
- Configured a backup location for Velero

>NOTE:
Velero supports backing up and restoring Kubernetes volumes attached to pods from the file system of the volumes through the [FSB](https://velero.io/docs/v1.10/file-system-backup/) feature; to use it, make sure the `--use-node-agent` option is passed when installing Velero.
However, `hostPath` volumes are not supported, so verify that the `kamaji-etcd` datastore is using, at least, a [`local volume`](https://kubernetes.io/docs/concepts/storage/volumes/#local).

## Backup step

This example shows how to backup and restore a `kamaji-etcd` datastore called `dedicated` and related resources using the `--include-namespaces` tag. Assume the datastore is deployed into a namespace called `dedicated`.

Because `kamaji-etcd` datastore is a stateful workload, you need to add annotations for the stateful pods with the volume name as the default [opt-in](https://velero.io/docs/v1.10/file-system-backup/#using-opt-in-pod-volume-backup) approach used by Velero:

```
kubectl -n dedicated annotate pods dedicated-0 dedicated-1 dedicated-2  backup.velero.io/backup-volumes=data
```

As alternative to annotate pods, use the [opt-out](https://velero.io/docs/v1.10/file-system-backup/#using-opt-out-pod-volume-backup) approach leaving Velero to back up all pod volumes using FSB.

Create a backup:

```
velero backup create kamaji-etcd-dedicated-backup --include-namespaces dedicated
```

then, verify the backup job status:

```
velero backup get

NAME						   STATUS     ERRORS   WARNINGS   CREATED                         EXPIRES   STORAGE LOCATION   SELECTOR
kamaji-etcd-dedicated-backup   Completed  0        0          2023-02-23 17:45:13 +0100 CET   27d       cloudian           <none>
```

in case of problems, you can get more information by running:

```
velero backup describe kamaji-etcd-dedicated-backup
```

## Restore step
In case of disaster recovery to a new Kamaji Management Cluster, make sure that the Storage Class installed on the target cluster matches the source cluster, or change the Storage Class [during restore](https://velero.io/docs/main/restore-reference/#changing-pvpvc-storage-classes).

To exercise the restore, delete any previous instance of the datastore:

```
kubectl delete namespace dedicated 
```

and then execute:

```
velero restore create kamaji-etcd-dedicated-restore \
    --from-backup kamaji-etcd-dedicated-backup 
```

Verify the restore job status:

```
velero restore get kamaji-etcd-dedicated-restore

```

in case of problems, you can get more information by running:

```
velero restore describe kamaji-etcd-dedicated-backup
```

Verify the presence of the desired datastore :

```
kubectl get datastore

NAME                   DRIVER   AGE
dedicated              etcd     6m
```

and finally, check that target PVCs are in _bound_ status:

```
kubectl get pvc -A

NAMESPACE     NAME               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
dedicated     data-dedicated-0   Bound    pvc-a5c66737-ef78-4689-b863-037f8382ed78   10Gi       RWO            local-path     6m
dedicated     data-dedicated-1   Bound    pvc-1e9f77eb-89f3-4256-9508-c18b71fca7ea   10Gi       RWO            local-path     6m
dedicated     data-dedicated-2   Bound    pvc-957c4802-1e7c-4f37-ac01-b89ad1fa9fdb   10Gi       RWO            local-path     6m
[...]
```

Before to implement the Disaster Recovery process, make sure to consult the Velero official [documentation](https://velero.io/docs).