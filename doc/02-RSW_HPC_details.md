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
* make one compute node available all the time to ensure a fast R session start.  

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

# R installation 

## General Summary

* We use [R binaries as provided by RStudio](https://docs.rstudio.com/resources/install-r/)
* Any OS provided R versions are removed.
* R is configured to use a compatible Java installation 
* R is installed on the Head node only and then shared via NFS to the compute nodes
* Package repositories
    * **CRAN** and **BioConductor** are preconfigured
    * make use of the [**public RStudio package manager**](https://packagemanager.rstudio.com/), especially its binaries for CRAN
    * BioConductor can be used via `install.packages()` in addition to `BiocManager::install()`
    * CRAN uses a **time-based snapshot** for each R version that is up to **60 days later than the release date** of the corresponding R version. 
    * Only recommended packages preinstalled. 
    * Package repository information, modified `.libPaths()` settings as well as various environment variables are stored primarily in `Rprofile.site` and `Renviron.site` for each R version.  
  

## Package configuration

[CRAN](https://cran.r-project.org) and [BioConductor](https://bioconductor.org) are fairly different repositories for R packages, starting with their different scope. 

CRAN is constantly evolving (packages being added and updated every day) while BioConductor produces versioned releases of the repository. Such a version is then compatible with a single R version. In order to mimick compatibility with an R version, we use a time-based snapshot of CRAN with a time stamp about 60 days post the R version release. This should ensure that sufficient time has elapsed to fix any general issues in R packages as a consequence of the new R version. On the other hand the time stamp is not too far away either to start introducing any breakages from too new versions of R packages. 

## Managing central R installation on the  Head node

The advantage of a central R installation is the easier management of configuration files (e.g. `Rprofile.site` and `Renviron.site`). It also makes upgrading or adding newer R versions much more straightforward. 

The installed R versions are shared via NFS to the compute nodes. In order to ensure the operating system dependencies of the R binaries are met on the compute nodes, those dependencies are automatically added to the compute nodes upon boot time. 

## Java support 

An inherently problematic issue in R is Java integration. We are using OpenJDK 8 for R versions 3.x and OpenJDK 11 for R Versions 4.x. We are setting `JAVA_HOME` appropriately. 

## Design choices
* Install R in `/opt/rstudio` on the head node.
* Export `/opt/rstudio` via NFS and mount it on compute nodes
* Copy the OS dependencies of each R version in a file named `.depends` into the base directory of each R version. This information is then used to install those dependencies if a compute nodes is provisioned.
* BioConductor repositories are pre-defined in `Rprofile.site` in the appropriate compatible bioconductor version so that they can directly be used via `install.packages()`
* CRAN repository is configured to use a time-based snapshot with a snapshot date of about 60 days past the corresponding R release date. 
* `JAVA_HOME` is 
   * `/usr/lib/jvm/java-8-openjdk-amd64/` for R 3.x
   * `/usr/lib/jvm/java-11-openjdk-amd64/` for R 4.x

# RStudio IDE integration 

## General Summary

* all the auxiliary packages (e.g. `rmarkdown`, `rsconnect`, `shiny` are installed in a separate folder for each R version and added via `.libPaths()`. 
* `RSTUDIO_DISABLE_PACKAGE_INSTALL_PROMPT=yes` is set in `launcher-env` to disable checking for the auxiliary packages such as `rmarkdown`, `rsconnect`, `shiny`, ... 


## Auxiliary packages

RStudio IDE prodides great integration to facilitate the development of shiny apps, producing RMarkdown documents etc... This integration is achieved by calling the [appropriate auxiliary R packages](https://github.com/rstudio/rstudio/blob/main/src/cpp/session/resources/dependencies/r-packages.json) in the background. 

A default installation of R typically only contains the recommended packages. Any other package needs to be installed either by the user or the admin of a given system. In this case we pre-install all needed auxiliary packages for a given R version (using its repository setup) and add them in a separate folder that is then added via `.libPaths()`. As a consequence we can set `RSTUDIO_DISABLE_PACKAGE_INSTALL_PROMPT=yes` in `launcher-env` for increased performance and better user experience. 

## [Extended R Version definition](https://docs.rstudio.com/ide/server-pro/r_versions/using_multiple_versions_of_r.html#extended-r-version-definitions)

Each installed version of R is automatically added into the `r-versions` file and `Path`, `Label`, `Repo` and `Script` defined for each (For `Script`, see below "Java support"). `Path` corresponds to the base directory of the R installation (e.g. `/opt/R/4.2.0`), `Label` is always set to "R". `Repo` points to a config file named `repos-x.y.z.conf` (where `x.y.z` is the R version number). It contains the same repository configuration as in `Rprofile.site`. 



## Java support 

Since RSW does nor respect various configuration files of R (e.g. `ldpaths`) we need to add this file as a script to each R version definition.

## Design choices

* Install auxiliary packages into `/opt/rstudio/rver/x.y.z` where `x.y.z` is the R version number. Add the path to the `.libPaths()` variable in `Rprofile.site`
* `r-versions` definition in `/opt/rstudio/etc/rstudio/r-versions` with repo definition in `/opt/rstudio/etc/rstudio/repos/repos-x.y.z.conf`

# renv integration 

## General Summary

* a global `renv` package cache is used, accessible read-write by everyone
* `RENV_PATHS_PREFIX_AUTO=TRUE` is set and `RENV_PATHS_CACHE` points to the shared location that created with a very open ACL (`Renviron.site`). 

## `renv` cache

The `renv` cache is set up with a very open ACL, i.e. 

```
user::rwx
group::rwx
mask::rwx
other::rwx
default:user::rwx
default:group::rwx
default:mask::rwx
default:other::rwx
```

This allows any user to write into and read from the `renv` cache. 

The location of the `renv` cache is defined by `RENV_PATHS_CACHE`. `RENV_PATHS_PREFIX_AUTO=TRUE` ensures that `renv` is using different cache subfolders for each linux distribution. 

## Design choices

`/scratch/renv` lives on the HPC cluster's `/scratch` file system shared by the head node and available on every compute node. 

```
RENV_PATHS_CACHE=/scratch/renv
RENV_PATHS_PREFIX_AUTO=TRUE
```
ACL as defined above applied to `/scratch/renv`.