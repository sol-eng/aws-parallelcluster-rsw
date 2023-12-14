#!/bin/bash

CLUSTERNAME="add-cluster-name"
S3_BUCKETNAME="add-bucket-name"
SECURITYGROUP_RSW="sg-##"
SUBNETID="subnet-##"
REGION="eu-west-1"
KEY="add-keyname"

# Posit Workbench Version
PWB_VER=2022.07.2-576.pro12
PWB_VER=2022.12.0-353.pro20
PWB_VER=2023.09.1-494.pro2
#PWB_VER=2023.05.0-daily-312.pro2
# SLURM Version - use only "-" to resemble git tag version
SLURM_VER=22-05-5-1

CERT="/Users/michael/projects/aws/certs/michael.pem"

# create random rstudio password and store it in a secret 

## rstudiopw will be a 8 character hex string (2^32 possibilities)
rstudiopw=`openssl rand -hex 4`

## let's label the secret so it can be recognised again 
secret_name="rstudiopw-cluster-$CLUSTERNAME"
aws secretsmanager create-secret \
    --name $secret_name \
    --description "Secret for rstudio user password on AWS ParallelCluster $CLUSTERNAME" \
    --secret-string "$rstudiopw"

if [ $? -eq 254 ]; then
   secret_id=`aws secretsmanager list-secrets --filters Key=name,Values=$secret_name | jq -r '.SecretList | .[]| .ARN'`
   echo "secret $secret_name already exists, we need to update it"
   aws secretsmanager update-secret \
      --secret-id "$secret_id" \
      --secret-string "$rstudiopw"
else
   secret_id=`aws secretsmanager list-secrets --filters Key=name,Values=$secret_name | jq -r '.SecretList | .[]| .ARN'`
fi

get_secret=`aws secretsmanager get-secret-value --secret-id $secret_id | jq -r '.SecretString'`

echo "rstudio user password is now set to $get_secret"



rm -rf tmp
mkdir -p tmp
cp -Rf scripts/* tmp
cat scripts/aliases.sh | sed "s#CERT#${CERT}#" > tmp/aliases.sh
cat scripts/install-rsw.sh | sed "s/PWB_VER/$PWB_VER/" \
   | sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" \
   | sed "s#SECRET#$get_secret#g"> tmp/install-rsw.sh

cat scripts/install-compute.sh | sed "s#SECRET#$get_secret#g" > tmp/install-compute.sh

for i in scripts/*.sdef      
do
   if [[ $PWB_VER =~ "2022.12" ]]; then
      cat $i | sed "s/PWB_VER/$PWB_VER/" | sed "s/SLURM_VER/$SLURM_VER/" | sed "s#r-session-complete:#r-session-complete-preview:dev-#" > ${i/scripts/tmp/}
   else 
      PWB_VER=`echo $PWB_VER | sed 's/\-.*//'`
      cat $i | sed "s/PWB_VER/$PWB_VER/" | sed "s/SLURM_VER/$SLURM_VER/"> ${i/scripts/tmp/}
   fi
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
