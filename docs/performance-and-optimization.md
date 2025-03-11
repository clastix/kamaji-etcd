# Performance and Optimization

If your `etcd` starts to behave slow or logs start showing messages like this: `"msg":"leader failed to send out heartbeat on time; took too long, leader is overloaded likely from slow disk"`, your storage might be too slow for `etcd` or the server might be doing too much for `etcd` to operate properly:

What can you do to the verify the performance of your storage. The biggest factor is the storage latency. If it is not well below `10ms` in the `99th` percentile, you will see warnings in the `etcd` logs. We can test this with a tool called **FIO** (Flexible I/O Tester) as stated below. Credits to [Matteo Olivi](https://github.com/matteoolivi) and [Mike Spreitzer](https://github.com/MikeSpreitzer) for their original [paper](https://www.ibm.com/cloud/blog/using-fio-to-tell-whether-your-storage-is-fast-enough-for-etcd) at IBM.

## Testing etcd performance
Assuming Ubuntu OS, install `fio`:

```
sudo apt install -y fio
```

To test the storage, create a directory on the device the `etcd` is using and then run the `fio` command:

```bash
export PATH=/usr/local/bin:$PATH
mkdir test-data
fio --rw=write --ioengine=sync --fdatasync=1 --directory=test-data --size=100m --bs=2300 --name=disk-bench
```

Below is an example of the output:

```
disk-bench: (g=0): rw=write, bs=(R) 2300B-2300B, (W) 2300B-2300B, (T) 2300B-2300B, ioengine=sync, iodepth=1
fio-3.15-23-g937e
Starting 1 process
disk-bench: Laying out IO file (1 file / 100MiB)
Jobs: 1 (f=1): [W(1)][100.0%][w=2684KiB/s][w=1195 IOPS][eta 00m:00s]
disk-bench: (groupid=0, jobs=1): err= 0: pid=21203: Sun Aug 11 23:47:30 2019
  write: IOPS=1196, BW=2687KiB/s (2752kB/s)(99.0MiB/38105msec)
    clat (nsec): min=2840, max=99026, avg=8551.56, stdev=3187.53
      lat (nsec): min=3337, max=99664, avg=9191.92, stdev=3285.92
    clat percentiles (nsec):
      |  1.00th=[ 4640],  5.00th=[ 5536], 10.00th=[ 5728], 20.00th=[ 6176],
      | 30.00th=[ 6624], 40.00th=[ 7264], 50.00th=[ 7968], 60.00th=[ 8768],
      | 70.00th=[ 9408], 80.00th=[10304], 90.00th=[11840], 95.00th=[13760],
      | 99.00th=[19328], 99.50th=[23168], 99.90th=[35584], 99.95th=[44288],
      | 99.99th=[63744]
    bw (  KiB/s): min= 2398, max= 2852, per=99.95%, avg=2685.79, stdev=104.84, samples=76
    iops        : min= 1068, max= 1270, avg=1195.96, stdev=46.66, samples=76
  lat (usec)   : 4=0.52%, 10=76.28%, 20=22.34%, 50=0.82%, 100=0.04%
  fsync/fdatasync/sync_file_range:
    sync (usec): min=352, max=21253, avg=822.36, stdev=652.94
    sync percentiles (usec):
      |  1.00th=[  400],  5.00th=[  420], 10.00th=[  437], 20.00th=[  457],
      | 30.00th=[  478], 40.00th=[  529], 50.00th=[  906], 60.00th=[  947],
      | 70.00th=[  988], 80.00th=[ 1020], 90.00th=[ 1090], 95.00th=[ 1156],
      | 99.00th=[ 2245], 99.50th=[ 5932], 99.90th=[ 8717], 99.95th=[11600],
      | 99.99th=[16581]
  cpu          : usr=0.79%, sys=7.38%, ctx=119920, majf=0, minf=35
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
      submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
      complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
      issued rwts: total=0,45590,0,0 short=45590,0,0,0 dropped=0,0,0,0
      latency   : target=0, window=0, percentile=100.00%, depth=1
Run status group 0 (all jobs):
  WRITE: bw=2687KiB/s (2752kB/s), 2687KiB/s-2687KiB/s (2752kB/s-2752kB/s), io=99.0MiB (105MB), run=38105-38105msec
Disk stats (read/write):
  xvda: ios=0/96829, merge=0/3, ticks=0/47440, in_queue=47432, util=92.25%
```

In the `fsync` data section you can see that the 99th percentile is `2245` or about `2.2ms` of latency. This storage is well suited for an `etcd` node. The `etcd` documentation suggests that for storage to be fast enough, the `99th` percentile of `fdatasync` invocations when writing to the `WAL` file must be less than `10ms`. But what if your storage is not fast enough? 

## Remediation
The simple solution is to upgrade the storage but that isn't always an option. There are things you can do to optimize your storage so that `etcd` is happy.

- Don't run `etcd` on a node with other roles. A general rule of thumb is to never have the worker role on the same node as etcd. However many environments have etcd and controlplane roles on the same node and run just fine. If this is the case for your environment then you should consider separating etcd and controlplane nodes.

- If you have separated `etcd` and the controlplane node and are still having issues, you can mount a separate volume for `etcd` so that read write operations for everything else on the node do not impact `etcd` performance. This is mostly applicable to Cloud hosted nodes since each volume mounted has its own allocated set of resources.

- If you are on a dedicated server and would like to separate `etcd` read write operations from the rest of the server, you should install a new storage device for `etcd` mounts.

- Always use SSDs for your `etcd` nodes, whether it is metal, virtual, or in the Cloud.

- Set the priority of the `etcd` container so that it is higher than other processes but not too high that it overwhelms the server.

```bash
ionice -c2 -n0 -p `pgrep -x etcd`
```
