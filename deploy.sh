#!/bin/bash

CLUSTERNAME="demo2"
S3_BUCKETNAME="hpc-scripts1234"
SECURITYGROUP_RSW="sg-0d432b9a4aeea0dd6"
SUBNETID="subnet-9bbd91c1"
REGION="eu-west-1"
KEY="michael"
CERT="/Users/michael/projects/aws/certs/michael.pem"

cat scripts/aliases.tmpl | sed "s#CERT#${CERT}#" > scripts/aliases.sh
cat scripts/install-rsw.sh.tmpl | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" > scripts/install-rsw.sh
cat scripts/install-compute.sh.tmpl | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" > scripts/install-compute.sh
aws s3 cp scripts/ s3://${S3_BUCKETNAME} --recursive --exclude security-group.sh --exclude *.tmpl 

cat config/cluster-config-wb.tmpl | \
	sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" | \
        sed "s#SECURITYGROUP_RSW#${SECURITYGROUP_RSW}#g" | \
        sed "s#SUBNETID#${SUBNETID}#g" | \
        sed "s#REGION#${REGION}#g" | \
        sed "s#KEY#${KEY}#g"  \
	> config/cluster-config-wb.yaml
pcluster create-cluster --cluster-name="$CLUSTERNAME" --cluster-config=config/cluster-config-wb.yaml --rollback-on-failure false 
