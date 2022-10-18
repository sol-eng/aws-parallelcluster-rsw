#!/bin/bash

CLUSTERNAME="demo2"
S3_BUCKETNAME="hpc-scripts1234"
SECURITYGROUP_RSW="sg-0838ae772a776ab8e"
SUBNETID="subnet-cd7e8c86"
REGION="eu-west-1"
KEY="michael"
CERT="/Users/michael/projects/aws/certs/michael.pem"

cat scripts/aliases.tmpl | sed "s#CERT#${CERT}#" > scripts/aliases.sh
cat scripts/install-rsw.sh.tmpl | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" > scripts/install-rsw.sh
aws s3 cp scripts/ s3://${S3_BUCKETNAME} --recursive --exclude security-group.sh --exclude *.tmpl 

cat config/cluster-config-wb.tmpl | \
	sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" | \
        sed "s#SECURITYGROUP_RSW#${SECURITYGROUP_RSW}#g" | \
        sed "s#SUBNETID#${SUBNETID}#g" | \
        sed "s#REGION#${REGION}#g" | \
        sed "s#KEY#${KEY}#g"  \
	> config/cluster-config-wb.yaml
pcluster create-cluster --cluster-name="$CLUSTERNAME" --cluster-config=config/cluster-config-wb.yaml --rollback-on-failure false 
