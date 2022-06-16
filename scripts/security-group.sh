#!/bin/bash

if [ -z $1 ]; then 
   echo "please specify vpc name as argument, e.g. 'vpc-xyz'"
   exit 1 
fi

aws ec2 create-security-group --group-name rsw \
    --description "RStudio Workbench Port" \
    --vpc-id $1
aws ec2 authorize-security-group-ingress \
    --group-name rsw \
    --protocol tcp \
    --port 8787 \
    --cidr 0.0.0.0/0
