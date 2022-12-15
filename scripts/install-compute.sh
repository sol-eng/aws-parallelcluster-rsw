#!/bin/bash

apt-get update -y

#Install Java support
apt-get install -y openjdk-11-jdk openjdk-8-jdk

# install venv support 
apt-get install -y python3.8-venv

#R package deps (ragg)
apt-get install -y libfreetype6-dev libpng-dev libtiff5-dev

# Add sample user 
groupadd --system --gid 1001 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 1001 rstudio

echo -e "rstudio\nrstudio" | passwd rstudio

apt-get install -y libzmq3-dev  libglpk40 libnode-dev

#mount various FS
grep slurm /etc/fstab | sed 's#/opt/slurm#/usr/lib/rstudio-server#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/R#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/rstudio#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/scratch#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/apptainer#g' | sudo tee -a /etc/fstab

mkdir -p /usr/lib/rstudio-server /opt/{R,rstudio,apptainer} /scratch

mount -a

#Install RSW Dependencies
apt-get install -y rrdtool psmisc libapparmor1 libedit2 sudo lsb-release  libclang-dev libsqlite3-0 libpq5  libc6

#Install R dependencies
apt-get install -y `cat /opt/R/$/.depends | sed 's#,##g'`

rm -rf /etc/profile.d/modules.sh

#remove default R version (too old)
apt remove -y r-base r-base-core r-base-dev r-base-html r-doc-html

#Install apptainer
export APPTAINER_VER=1.1.4
apt-get update -y 
apt-get install -y gdebi-core
for name in apptainer apptainer-suid
do
   wget https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VER}/${name}_${APPTAINER_VER}_amd64.deb && \
        gdebi -n ${name}_${APPTAINER_VER}_amd64.deb && \
        rm -f ${name}_${APPTAINER_VER}_amd64.deb*
done

#Update CUDA and add cuDNN
if ( lspci | grep NVIDIA ); then 
   wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
   mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
   apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
   add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
   apt-get update
   apt-get -y install cuda libcudnn8-dev
fi
