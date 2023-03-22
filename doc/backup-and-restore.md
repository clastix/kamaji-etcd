# Backup and restore

Kamaji “datastores" are just regular stateful pods scheduled on top of a choosen admin cluster; as such, you can take advantage of the same backup and restore methods that you would use to maintain the standard workload.

This guide will assist you in how to backup and restore datastore resources on the admin cluster using [Velero](https://tanzu.vmware.com/developer/guides/what-is-velero/).

## Prerequisites

Before proceeding with the next steps, we assume that the following prerequisites are met:

- Working admin cluster
- Working datastore resource
- Velero binary installed on the operator VM
- Velero installed on the admin cluster
- Configured backup location (e.g. S3) for velero

>NOTE:
Velero supports backing up and restoring Kubernetes volumes attached to pods from the file system of the volumes through the [FSB](https://velero.io/docs/v1.10/file-system-backup/) feature; to use it, make sure the `--use-node-agent` option is passed when installing Velero.
However, `hostPath` volumes are not supported, so verify that the `kamaji-etcd` datastore is using, at least, a [`local volume`](https://kubernetes.io/docs/concepts/storage/volumes/#local).

## Backup step

This example shows how to backup and restore a `kamaji-etcd` datastore called `dedicated` and related resources using the `--include-namespaces` tag. Assume the datastore is deployed into a namespace called `dedicated`.

Because `kamaji-etcd` datastore is a stateful app, you need to add annotations for the stateful pods with the volume name as the default [opt-in](https://velero.io/docs/v1.10/file-system-backup/#using-opt-in-pod-volume-backup) approach used by Velero:

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

>WARNING: We assume that the restore takes place on the same cluster from which you backed up. In case of disaster recovery, make sure that the storage-classes installed on the target cluster match the backup ones, OR, change the PV/PVC Storage Classes [during restore](https://velero.io/docs/main/restore-reference/#changing-pvpvc-storage-classes).

To restore just the desired datastore, simply execute:

```
velero restore create kamaji-etcd-dedicated-restore \
    --from-backup kamaji-etcd-dedicated-backup 
```

then, verify the restore job status:

```
velero restore get

NAME                        		BACKUP              			  STATUS      STARTED                         COMPLETED                       ERRORS   WARNINGS   CREATED                         SELECTOR
kamaji-etcd-dedicated-restore      	kamaji-etcd-dedicated-backup      Completed   2023-02-24 12:31:39 +0100 CET   2023-02-24 12:31:40 +0100 CET   0        0          2023-02-24 12:31:39 +0100 CET   <none>
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

and finally, check that target PVCs are in _Bound_ status:

```
kubectl get pvc -A

NAMESPACE         NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
dedicated         data-dedicated-0              Bound    pvc-a5c66737-ef78-4689-b863-037f8382ed78   10Gi       RWO            local-path     6m
dedicated         data-dedicated-1              Bound    pvc-1e9f77eb-89f3-4256-9508-c18b71fca7ea   10Gi       RWO            local-path     6m
dedicated         data-dedicated-2              Bound    pvc-957c4802-1e7c-4f37-ac01-b89ad1fa9fdb   10Gi       RWO            local-path     6m
[...]
```
