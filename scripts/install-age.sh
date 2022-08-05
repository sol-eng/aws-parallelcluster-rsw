apt-get install -y docker-compose
mkdir -p /opt/age-license
pushd /opt/age-license
for i in altair_licensing_15.0.linux_x64.bin Dockerfile.age-license start-lic.sh docker-compose.yml age.dat
do
aws s3 cp s3://hpc-scripts1234/$i . 
done

chmod +x start-lic.sh 
docker-compose up -d 

rm -f altair_licensing_15.0.linux_x64.bin 

popd

mkdir -p /opt/age/8.7.1

if ! ( grep "/opt/age" /etc/exports ); then 
   grep slurm /etc/exports | sed 's#/opt/slurm#/opt/age#' | sudo tee -a /etc/exports
exportfs -ar
fi

pushd /opt/age/8.7.1
for i in ge-8.7.1-bin-lx-amd64.tar.gz ge-8.7.1-common.tar.gz
do
aws s3 cp s3://hpc-scripts1234/$i .
tar xfvz $i
rm -rf $i 
done 

popd

groupadd -g 6200 ageadmin 
useradd -s /bin/bash -u 6200 -g 6200 ageadmin -m 

export SGE_ROOT=/opt/age/8.7.1

sed -i 's/\[ $1 =/\[ "$1" =/' /opt/age/8.7.1/util/setfileperm.sh
echo "yes" | bash /opt/age/8.7.1/util/setfileperm.sh $SGE_ROOT

cp util/install_modules/inst_template.conf

./inst_sge -m -auto full-path-to-configuration-file

