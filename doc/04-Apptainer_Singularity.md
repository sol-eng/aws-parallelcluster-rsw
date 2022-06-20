# Apptainer / Singularity

## Introduction

[Apptainer](https://apptainer.org/)/[Singularity](https://hpc.nih.gov/apps/singularity.html) is the most widely used container system for HPC. Singularity was renamed to Apptainer when it joined the Linux Foundation in late 2021. 

Running containers at scale has become very popular thanks to the likes of [docker](https://www.docker.com/) and various container orchestration platforms, e.g. [kubernetes](https://kubernetes.io/). 

Many complex scientific softwares today offer the ability to run them in docker containers. This is not only to ensure reproducibility but also to make sure that all dependencies are there in the right version etc... for best functionality. 

HPC clusters exist much longer, particularly [Beowulf](https://en.wikipedia.org/wiki/Beowulf_cluster) clusters started in 1994. It is those HPC systems, built mainly with networked, identical commodity servers, that have become main stream HPC today. 

These HPC clusters comprise of a few to 10's of thousands of servers, all connected via a network and governed by a load & resource manager (e.g. SLURM). 

Users usually submit jobs to such an HPC cluster by specifying all relevant details (e.g. which software, what input data, where to store outputs, how many CPU's, how much memory, ...). The scheduler in combination with the chosen programming framework (e.g. MPI for distributed computing) then takes care of the execution of the computation. 

Docker container only came into existence in 2013, almost 20 years after Beowulf HPC. 

The goal of Apptainer/Singularity is to enable the exeuction of containers in user space. Docker containers by default need admin privileges to run. Granting admin privileges to every user is not possible on a large HPC system. 

In addition to Apptainer/Singularity there is also [Shifter](https://github.com/NERSC/shifter), a project with the same goals than Apptainer/Singularity. While technologically potentially superior to Apptainer/Singularity, Shifter does not seem to be as popular as Apptainer/Singularity.

Apptainer can take any docker container and transform it into the Apptainer format which for the most part is the docker container converted into a chroot fs using squashfs for compression. The result is a flat file that can be run via the apptainer binary. 

Apptainer can also use a docker container as a starting point (bootstrap9 and add additional features to it before saving it into the flat file that is the apptainer image. 

Finally apptainer also can provide an apptainer registry where apptainer containers can be stored. 

## Why Apptainer with RStudio Workbench ?

**Problem:** Native installation of RStudio Workbench + SLURM launcher on a HPC system is very intrusive 

 * deploying of tarballs into `/usr/lib/rstudio-server` (or using a workaround to avoid doing that)
 * installing of additional software like `R` and `Python` on the HPC can cause incompatibilities with other softwares already existing on the HPC cluster

**Solution:** Add Apptainer/Singularity integration into the SLURM setup (which already could be in place for other projects on the HPC cluster). Past that you will only need to build the Apptainer container that includes the RSW session components and the relevant other software (R, Python, VSCode, ...). Finally you can configure the SLURM launcher to offer the possibility to add a container name when launching a new session. 

## How to integration Apptainer with RStudio Workbench

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

Again, this is already enables as part of the AWS ParallelCLuster deployment. 

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

Reusing existing components again is used here. As a consequence we are using the `r-session-complete` containers as a starting point to bootstrap from. We then add all the R and RSW specific integrations (see earlier chapters). Finally we also build the same SLURM version into the container so that the R session within the container can be used to submit against the HPC cluster (e.g. via Launcher jobs or directly interfacing with the HPC via `batchtools` and `clustermq`).