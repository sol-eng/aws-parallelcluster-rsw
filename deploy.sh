#!/bin/bash

CLUSTERNAME="demo66"
S3_BUCKETNAME="hpc-scripts1234"
SECURITYGROUP_RSW="sg-0838ae772a776ab8e"
SUBNETID="subnet-cd7e8c86"
REGION="eu-west-1"
KEY="michael"

# Posit Workbench Version
PWB_VER=2022.07.2-576.pro12
#PWB_VER=2022.12.0-354.pro1

# SLURM Version - use only "-" to resemble git tag version
SLURM_VER=22-05-5-1

CERT="/Users/michael/projects/aws/certs/michael.pem"

rm -rf tmp
mkdir -p tmp
cp -Rf scripts/* tmp
cat scripts/aliases.sh | sed "s#CERT#${CERT}#" > tmp/aliases.sh
cat scripts/install-rsw.sh | sed "s/PWB_VER/$PWB_VER/" | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" > tmp/install-rsw.sh

for i in scripts/*.sdef      
do
cat $i | sed "s/PWB_VER/$PWB_VER/" | sed "s/SLURM_VER/$SLURM_VER/"> ${i/scripts/tmp/}
done

aws s3 cp tmp/ s3://${S3_BUCKETNAME} --recursive 

cat config/cluster-config-wb.tmpl | \
	sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" | \
        sed "s#SECURITYGROUP_RSW#${SECURITYGROUP_RSW}#g" | \
        sed "s#SUBNETID#${SUBNETID}#g" | \
        sed "s#REGION#${REGION}#g" | \
        sed "s#KEY#${KEY}#g"  \
	> config/cluster-config-wb.yaml
pcluster create-cluster --cluster-name="$CLUSTERNAME" --cluster-config=config/cluster-config-wb.yaml --rollback-on-failure false 
