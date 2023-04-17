#!/bin/bash

CLUSTERNAME="demo85"
S3_BUCKETNAME="hpc-scripts1234"
SECURITYGROUP_RSW="sg-0838ae772a776ab8e"
SUBNETID="subnet-cd7e8c86"
REGION="eu-west-1"
KEY="michael"

# Posit Workbench Version
PWB_VER=2022.07.2-576.pro12
PWB_VER=2022.12.0-353.pro20
PWB_VER=2023.03.0-386.pro1

# SLURM Version - use only "-" to resemble git tag version
SLURM_VER=22-05-5-1

CERT="/Users/michael/projects/aws/certs/michael.pem"

rm -rf tmp
mkdir -p tmp
cp -Rf scripts/* tmp
cat scripts/aliases.sh | sed "s#CERT#${CERT}#" > tmp/aliases.sh
cat scripts/install-rsw.sh | sed "s/PWB_VER/$PWB_VER/" | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" > tmp/install-rsw.sh

# make sure the correct r-session-complete version is used for singularity
#if [[ $PWB_VER =~ "2022.12" || $PWB_VER =~ "2023.03"]]; then
#   PWB_VER=$( echo $PWB_VER | cut -d "-" -f 1 )
#fi

aws s3 cp tmp/ s3://${S3_BUCKETNAME} --recursive 

cat config/cluster-config-wb.tmpl | \
	sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" | \
        sed "s#SECURITYGROUP_RSW#${SECURITYGROUP_RSW}#g" | \
        sed "s#SUBNETID#${SUBNETID}#g" | \
        sed "s#REGION#${REGION}#g" | \
        sed "s#KEY#${KEY}#g"  \
	> config/cluster-config-wb.yaml
pcluster create-cluster --cluster-name="$CLUSTERNAME" --cluster-config=config/cluster-config-wb.yaml --rollback-on-failure false 
