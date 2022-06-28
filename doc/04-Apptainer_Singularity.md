# Apptainer / Singularity

## Introduction

[Apptainer](https://apptainer.org/)/[Singularity](https://hpc.nih.gov/apps/singularity.html) is the most widely used container system for HPC. Singularity was renamed to Apptainer when it joined the Linux Foundation in late 2021. 

Running containers at scale has become very popular thanks to the likes of [docker](https://www.docker.com/) and various container orchestration platforms, e.g. [Kubernetes](https://kubernetes.io/). 

Many complex scientific software today offer the ability to run them in docker containers. This is not only to ensure reproducibility but also to make sure that all dependencies are there in the right version etc... for best functionality. 

HPC clusters exist much longer, particularly [Beowulf](https://en.wikipedia.org/wiki/Beowulf_cluster) clusters started in 1994. It is those HPC systems, built mainly with networked, identical commodity servers, that have become main stream HPC today. 

These HPC clusters comprise of a few to 10's of thousands of servers, all connected via a network and governed by a load & resource manager (e.g. SLURM). 

Users usually submit jobs to such an HPC cluster by specifying all relevant details (e.g. which software, what input data, where to store outputs, how many CPU's, how much memory, ...). The scheduler in combination with the chosen programming framework (e.g. MPI for distributed computing) then takes care of the execution of the computation. 

Docker container only came into existence in 2013, almost 20 years after Beowulf HPC. 

The goal of Apptainer/Singularity is to enable the execution of containers in user space. Docker containers by default need admin privileges to run. Granting admin privileges to every user is not possible on a large HPC system. 

In addition to Apptainer/Singularity there is also [Shifter](https://github.com/NERSC/shifter), a project with the same goals than Apptainer/Singularity. While technologically potentially superior to Apptainer/Singularity, Shifter does not seem to be as popular as Apptainer/Singularity.

Apptainer can take any docker container and transform it into the Apptainer format which for the most part is the docker container converted into a chroot fs using squashfs for compression. The result is a flat file that can be run via the apptainer binary. 

Apptainer can also use a docker container as a starting point (bootstrap9 and add additional features to it before saving it into the flat file that is the apptainer image. 

Finally apptainer also can provide an apptainer registry where apptainer containers can be stored. 

## Why Apptainer with RStudio Workbench ?

**Problem:** Native installation of RStudio Workbench + SLURM launcher on a HPC system is very intrusive 

 * deploying of tar balls into `/usr/lib/rstudio-server` (or using a workaround to avoid doing that)
 * installing of additional software like `R` and `Python` on the HPC can cause incompatibilities with other software already existing on the HPC cluster

**Solution:** Add Apptainer/Singularity integration into the SLURM setup (which already could be in place for other projects on the HPC cluster). Past that you will only need to build the Apptainer container that includes the RSW session components and the relevant other software (R, Python, VSCode, ...). Finally you can configure the SLURM launcher to offer the possibility to add a container name when launching a new session. 

## Integration of Apptainer with RStudio Workbench

### Setting up of the SPANK Plugin for Apptainer/Singularity

SLURM comes with [SPANK](https://slurm.schedmd.com/spank.html) which basically allows you to customize/extend the slurm commands for additional features. 

For Apptainer/Singularity we add two command line parameters to `sbatch`/`srun`: `--singularity-container-path` and `--singularity-container` where the path points to the location of the Apptainer/Singularity Container and the second argument points to the file name of the container itself. 

In order to not reinvent the wheel, we are using an implementation that was originally developed at [GSI](https://git.gsi.de/SDE/slurm-singularity-exec/-/tree/master) which we extended further and tailored for our work. 

The setup of the SPANK plugin for Apptainer/Singularity is fully automated as part of the AWS ParallelCluster deployment. 

#### Design choices

* (Default) Location of all containers: `/opt/apptainer/containers`

### Configure the SLURM Launcher for Apptainer/Singularity

The only thing to be done is to add a line 
```
constraints=Container=singularity-container
```

to `launcher.slurm.conf`. This will expand the UI when launching a new session to include an empty free-text field named "Container". If the name of an apptainer container file is supplied there, RSW will launch a new session using this container. 

Again, this is already enables as part of the AWS ParallelCluster deployment. 

### Build the Apptainer container(s). 

The building of Apptainer container(s) is very time consuming. It is not done during the deployment of the HPC cluster as a a consequence. 

It can be done any time by running 

```
pushd /tmp
for i in *.sdef
do
/usr/bin/apptainer build \
	/opt/apptainer/containers/${i/sdef/simg} $i
done
popd
```

Reusing existing components again is used here. 
* As a consequence we are using the `r-session-complete` containers as a starting point to bootstrap from. 
* We then add all the R and RSW specific integrations (see earlier chapters). 
* Finally we also build the same SLURM version into the container so that the R session within the container can be used to submit against the HPC cluster (e.g. via Launcher jobs or directly interfacing with the HPC via `batchtools` and `clustermq`).

## Mixing pre-installed software (application stacks, SLURM installation) with containers

When it comes to container technology there is much greater flexibility when it comes to choosing operating systems (e.g. linux distribution and version). So one could easily run a container using RHEL7 on an Ubuntu 22.04 LT based cluster and so on.  

If one needs to use pre-installed software however (e.g. SLURM and app stack), one is tied to the same OS / Linux distro that the HPC cluster uses on a whole.
 
It is possible to integrate SLURM into the containers via mounting the appropriate folders at container run time. Same is true for the application stack with additional complexity for creating [extended version definition using the `Module` parameter](https://docs.rstudio.com/ide/server-pro/r-versions.html#using-multiple-versions-of-r-concurrently). 

In any case there is a strong interdependency between the application stack and the container that could obviate some of the benefits for reproducibility of the container (e.g. if the application stack settings are changed, the containers automatically inherit those changes although the containers themself have not changed). 

Also, especially when it comes to R, there always is a need for having the latest and greatest versions of the build tool chain (e.g. compilers, libraries, ...). This typically is in contrast to the Enterprise grade operating systems that are used to run HPC clusters. In containers however there is great flexibility to choose the most recent version of a certain linux distribution of choice that then also makes it more easy/straightforward to add the appropriate version of the build tool chain.   

Our recommendation therefore is to install R separately into the container and NOT use anything from the application stack. Only exception from this guidance would be if the R users would need to use additional software (e.g. commercial software with R interfaces). For the most use cases we are aware, however, the installation of R (and a compatible version of Python) within the container with NO dependency of the application stack should be good enough.

On the flip side, while the disconnect between the application stack and the containers is an advantage, if it comes to the SLURM integration it adds additional complexity. Under the proposed approach (building the same SLURM version within the container and only using `slurm.conf` from the HPC cluster setup) one would need to make sure that every time the HPC admins upgrade SLURM, the containers also should be checked and upgraded if necessary. 

## Use of `renv`

In our proposed setup, the `renv` cache still lives outside of the container. This is ok as it is setup in a way to accommodate various linux distros and is only transient in nature. Because it is in a central/shared location, storage utilization is optimized for disk space (everyone that will install `tidyverse` will use packages from the shared cache, not installing packages in his/her workspace) and installation speed (installing a package that already exists in the cache implies creating a symbolic link only rather than downloading it again and possibly compiling it from source).  

It is also important to point out, that such a shared cache does not exist for users that are only using `install.packages()` commands. Those users' package installations will still end up in their `R_LIBS_USER` folder. If one wanted to disable that, setting `R_LIBS_USER=/dev/null` in `Renviron.site` would be a solution. 

## Tied down containers for tightly controlled projects 

Under certain circumstances it can become necessary to only allow users to use a specific version of R with a very limited set of R packages in specific versions (without giving them the combination of reproducibility and version choice that they usually can have by using `renv`). In such cases the base container can be used and like with the auxiliary packages discussed in the RStudio IDE integration an additional `.libPaths()` be added where those additional packages can be pre-installed and installation of additional libraries disabled (see last section above).   
