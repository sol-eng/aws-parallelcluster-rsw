> **IMPORTANT: Please do not use AWS ParallelCluster version 3.6.0+ - Posit Workbench is currently not compatible with the SLURM version used in ParallelCluster 3.6.0+**


# aws-parallelcluster-rsw
An opinionated setup of RStudio Workbench (RSW) for the use with AWS ParallelCluster

# QuickStart

## python venv (one time setup) 

```
python3 -m venv aws-parallelcluster
source aws-parallelcluster/bin/activate
pip install --upgrade pip
pip install aws-parallelcluster 
```

Once done, a `source aws-parallelcluster/bin/activate` will activate the `venv`, a simple `deactivate` will deactivate it again. 


## Edit config variables

Edit lines 3 to 9 of `deploy.sh` to reflect the appropriate details of your environment. 

## Start the deployment 

Run `./deploy.sh`. This will copy scripts and config files to the existing S3 bucket and trigger the installation of the HPC cluster. 


# More information 

See [doc](./doc) folder. 


