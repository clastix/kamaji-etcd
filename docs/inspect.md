# Inspecting etcd Cluster
This guide explains how to run a `etcd` client pod to inspect the `kamaji-etcd` cluster and perform various operations.

## Running the etcd Client Pod

The `etcd-client.sh` script in the `scripts` directory can be used to create an etcd client pod with all necessary configurations and certificates mounted. Here's how to use it:

```bash
./etcd-client.sh [-e etcd_name] [-s etcd_client_service] [-n etcd_namespace]
```

### Script Parameters

- `-e`: Name of the etcd cluster (default: "kamaji-etcd")
- `-s`: Service name for etcd client connection (default: "kamaji-etcd-client")
- `-n`: Namespace where etcd is running (default: "kamaji-system")

### Using the Client Pod

1. Run the script to create the client pod:
   ```bash
   ./etcd-client.sh -e kamaji-etcd -s kamaji-etcd-client -n kamaji-system
   ```

2. Once the pod is created, connect to it using:
   ```bash
   kubectl exec -it etcd-client -n kamaji-system -- bash
   ```

3. Inside the pod, you can run various etcdctl commands:
   - List all etcd cluster members:
     ```bash
     etcdctl member list -w table
     ```
   - Check endpoint status:
     ```bash
     etcdctl endpoint status -w table
     ```
   - Check endpoint health:
     ```bash
     etcdctl endpoint health -w table
     ```
   - List all keys in etcd:
     ```bash
     etcdctl get / --prefix --keys-only
     ```

The client pod is pre-configured with:

- TLS certificates for secure communication
- Correct endpoints configuration
- Required environment variables

### Cleanup

To remove the client pod when finished:
```bash
kubectl delete pod etcd-client -n kamaji-system
```
This allows you to inspect and interact with the `kamaji-etcd` cluster without needing to install etcdctl on your local machine or manage certificates manually.
