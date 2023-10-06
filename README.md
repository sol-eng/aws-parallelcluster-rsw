> **IMPORTANT: ParallelCluster 3.6.0+ is compatible with Posit Workbench when using 2023.06.2+**


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

Also check in `config/cluster-config-wb.tmpl` whether you will need to set the tags - if you do, please make sure you supply a value to `rs:owner` which should be your eMail address. If not, you can remove whe whole `Tags:` section in the YAML template file. 

## Start the deployment 

Run `./deploy.sh`. This will copy scripts and config files to the existing S3 bucket and trigger the installation of the HPC cluster. 


# More information 

See [doc](./doc) folder. 


