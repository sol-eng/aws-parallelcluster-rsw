# AWS ParallelCluster

## High Level Overview

* SLURM as a scheduler
* 3 partitions, each with 5 nodes (unless stated otherwise, nodes are configured, but not provisioned/active)
    * **all**: 5 `t2.xlarge` instances, one node online all the time
    * **mpi**: 5 `c5n.18xlarge` instance with EFA enabled
    * **gpu**: 5 `p3.2xlarge` instances
* Head node with 100 GB of local storage acting as a SLURM Controller but also as a NFS server
* Port 8787 open on Head Node 