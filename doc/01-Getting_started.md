# Configure AWS access

## Install awscli

Follow instructions at https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html

## Configure SSO 

Either run "aws sso configure" or create ~/.aws/config with the following content 

```
[profile PowerUser-xyz]
sso_start_url = https://mycorp.awsapps.com/start
sso_region = us-east-1
sso_account_id = xyz
sso_role_name = PowerUser
region = us-east-1
```

`xyz` is the placeholder for your account number while `https://mycorp.awsapps.com/start` is a placeholder for the SSO URL of your company. 

## Add credentials for AWS account

Start the AWS SSO app in Okta. You will be presented a list of accounts you have access to - click on the ones you want to use, then select "Command line or programmatic access". Copy the respective content into ~/.aws/credentials in your home-directory.  

## Useful environment variables 

It is useful to set 

```
AWS_PROFILE=PowerUser-xyz
AWS_DEFAULT_REGION=us-east-1
```

in your session profile. Otherwise many of the AWS commands will force you to manually specify profile and region. 

## Testing SSO

You can run 

```
aws sso login 
```

to test if Single Sign On works. 

## Create S3 bucket 

In order to access custom shell scripts and other configurations, we need an S3 bucket to be set up. 

```
aws s3api create-bucket --bucket my-bucket-for-hpc-configs
```
where `my-bucket-for-hpc-configs` is a placeholder for the bucket name. 

# Parallel Cluster 

## python venv (one time setup) 

```
python3 -m venv aws-parallelcluster
source aws-parallelcluster/bin/activate
pip install --upgrade pip
pip install aws-parallelcluster 
```

Once done, a `source aws-parallelcluster/bin/activate` will activate the `venv`, a simple `deactivate` will deactivate it again. 


## Edit config variables

* Edit lines 3 to 9 of `deploy.sh` to reflect the appropriate details of your environment. 
* Once done, run `./deploy.sh`. This will copy scripts and config files to the existing S3 bucket and trigger the installation of the HPC cluster. 

## Bash aliases

For conveniency, `scripts/aliases.sh` defines a number of aliases for `pcluster` commands that make it much easier to work with. 

```
pcluster-create() { pcluster create-cluster --cluster-name="$1" --cluster-config=configs/cluster-config-wb.yaml}
pcluster-ssh() { pcluster ssh --cluster-name="$1" -i CERT }
pcluster-list() { pcluster list-clusters }
pcluster-desc() { pcluster describe-cluster --cluster-name="$1" }
pcluster-del() { pcluster delete-cluster --cluster-name="$1" }
```

`pcluster-list` will list you all currently active clusters. If you had a cluster up and running named `demo`, you then simply could ssh into that cluster via. `pcluster-ssh demo` and so on. 



## Following progress

You can follow progress of the build by running 
```
pcluster-list
```
or to get more specific information about test-hpc
```
pcluster-desc demo
```

## Logging in

Once you get "CREATION_COMPLETE" you can ssh into your new HPC cluster via
```
pcluster-ssh demo
```

## Debugging (WIP)

Sometimes things can go wrong. It is up to you to figure out what is going wrong. If things go wrong at cluster creation, you will see a CREATE\_FAILED and ROLLBBACK messages in the cluster status. In that case you can get the cluster stack events via 

```
pcluster get-cluster-stack-events --cluster-name test-hpc --region eu-west-1  \
			--query 'events[?resourceStatus==`CREATE\_FAILED`]'

```
which will then give you more hints to identify the actual log stream to look at. This stream you can view via

```
pcluster get-cluster-log-events --cluster-name test-hpc --region eu-west-1 \
			--log-stream-name ip-172-31-36-122.i-0d342c3e5a65af3de.cfn-init --limit 20
```

There also is a [extensive troubleshooting section](https://docs.aws.amazon.com/parallelcluster/latest/ug/troubleshooting-v3.html) on the offical AWS ParallelCluster Docs page.