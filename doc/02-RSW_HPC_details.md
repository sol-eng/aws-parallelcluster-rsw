# Details on the RSW Installation and its integration into the SLURM Cluster

# SLURM integration

## General ideas

* Install RSW on the SLURM Head node or on a submit node: The minimum requirement is that RSW must be installed on a submit node (SLURM client). On very large HPC clusters the RSW installation on a dedicated submit node is preferred while for small HPC clusters (10s of nodes) it is perfectly fine to have RSW installed on the SLURM Head node (which is also a submit node).

* Share RSW software to compute nodes via NFS. This makes upgrades much easier. You no longer need to separately upgrade the RSW server and the compute nodes. Once you upgrade RSW server, the clients are automatically upgraded as well. Also, you will not need to manually deploy a tarball to each compute node either.

* Have RSW configuration files in a shared non-standard location

* The RSW software and the RSW config files can be shared via an NFS export from the SLURM Head or via any other shared FS (Corporate NAS, EFS, FsX, ...)

## Design choices made for this implementation

* Install RSW on the SLURM Head node
* Install RSW config files into `/opt/rstudio/etc/rstudio`. Configure a `systemctl` override to define `RSTUDIO_CONFIG_DIR=/opt/rstudio/etc/rstudio`
* Export `/usr/lib/rstudio-server` from the head node and mount it on all the compute nodes
* Define [`launcher-sessions-callback-address`](https://rstudiopbc.atlassian.net/wiki/spaces/PRO/pages/49578078/Setting+up+SLURM+Launcher+with+RSW#5.-Define-launcher-sessions-callback-address) as `http://myip:8787` where `myip=$( curl http://checkip.amazonaws.com)`
* 

### `systemctl` override

We follow the [instructions](https://docs.rstudio.com/ide/server-pro/server_management/core_administrative_tasks.html#configure-service) or alternatively directly run

```
sudo mkdir -p /etc/systemd/system/rstudio-server.service.d/
cat << EOF | sudo tee -a /etc/systemd/system/rstudio-server.service.d/override.conf 
[Service]
Environment="RSTUDIO_CONFIG_DIR=/opt/rstudio/etc/rstudio"
EOF
sudo rstudio-server restart
```
and repeat the same for `rstudio-launcher` as well. 

### shared storage

As the name already mentions, this is a [shared storage path](https://docs.rstudio.com/ide/server-pro/r_sessions/project_sharing.html#shared-storage) where session information, the r-versions file etc... are stored. Such a storage path also must be defined when project sharing needs to work. This folder must be readable and writable by everyone and have the sticky bit set. For project sharing to work it also needs to support extended POSIX ACL's for [NFS v3](https://docs.rstudio.com/ide/server-pro/r_sessions/project_sharing.html#shared-storage) or [NFS v4](https://docs.rstudio.com/ide/server-pro/r_sessions/project_sharing.html#nfsv4) (which explicitly excludes the usage of Amazon EFS)

We create another directory under /opt/rstudio and call it shared-storage, e.g.

```
mkdir -p /opt/rstudio/shared-storage
```

and add

```
server-shared-storage-path=/opt/rstudio/shared-storage
```
into `rserver.conf`. 




