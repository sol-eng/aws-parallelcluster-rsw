# Introduction

AWS ParallelCluster is a set of scripts that allows the creation of an HPC cluster on-demand without the knowledge of any Cloud Scripting Languages (e.g. terraform, cloud formation, ....). 

The user needs to specify a YAML file that contains all the information and then can create the cluster with these specifics. 

With AWS ParallelCluster 3 only SLURM is supported as a scheduler. 

Customizations can be done in additional scripts (e.g. bash) that can be run at various stages of the respective node boot process. Existing AMI's can be customized as well to further speed up boot times. 

# Using the elasticity of AWS

One of the main benefits of parcluster is that it can utilize the elasticity of AWS. 

Upon cluster creation only the head/master node is spun up but all the compute nodes are not running while they virtually exist in the scheduler configuration. The maximum desired number of nodes in each queue must be specified beforehand. 

Once a user submits a job to the cluster, the SLURM scheduler will start to boot a compute node to meet the user's demand. Once the job is done and no other work/jobs has been submitted to that node, the node is being shut down again. With multiple users on such a cluster it is clear that specific scheduling strategies are needed in order to allow nodes to become idle again. 

# Interactive jobs

In a purely elastic setup there is a delay between submitting a job and the same job starting to run even if the cluster is empty. This is due to the time it takes to start up the node needed to run this job. Times can be minimized by using custom images etc... but wait times in the order of 1-2 minutes will remain. 

A way out of this is to have a number of nodes physically online all the time that can accommodate all the interactive work. 

# Why everything on-demand ? 

Initially the motion of spinning up entire HPC clusters on-demand sounds crazy let alone the dynamic spin-up and spin-down of compute nodes within such an HPC cluster. 

In times of cloud adoption and increasing usage, companies store data in the cloud (e.g. S3, EFS, ...) Those storage buckets are typically dispersed across various geographies. 

So in order to efficiently process data, you need to bring the computational tool-set (HPC in this case) close to the data (in order to avoid significant data transfer times and cost) 

Additional tools/technologies that are helpful in this regard is the S3 backed AWS FsX for Lustre where FsX can work as a high-performance proxy for any S3 bucket. The bucket would then look like a normal POSIX file system and data can be accessed read-write transparently. 

# What do other cloud providers offer ? 

Google Cloud (GCP) offers similar functionality than AWS. HPC environment can be spun up directly from the [Market Place](https://console.cloud.google.com/marketplace/product/schedmd-slurm-public/schedmd-slurm-gcp?pli=1) or by is using Terraform code for the [cluster creation](https://codelabs.developers.google.com/codelabs/hpc-slurm-on-gcp#0) 

Microsoft Azure Cloud provides multiple ways to run HPC workloads. They offer [CycleCloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) as an entry point but can provide [dedicated Cray Supercomputers](https://azure.microsoft.com/en-us/solutions/high-performance-computing/cray/) alongside other Azure Cloud services.

An interesting separator between AWS, Microsoft Azure and Google Cloud is their preferred choice of high performance (low latency) interconnect. Microsoft and Google offer [Infiniband](https://en.wikipedia.org/wiki/InfiniBand) for low latency while AWS provides their [Enhanced Fabric Adapter](https://aws.amazon.com/hpc/efa/). While Infiniband can provide latencies of about 1 microseconds or more, EFA only allows for 20+ microseconds. Depending on the real application the parallelization efficiency can be much better on Infiniband than on EFA. 

