#!/bin/bash

if ! [ -f /tmp/lsfsce10.2.0.12-x86_64.tar.gz ]; then 
	aws s3 cp s3://hpc-scripts1234/lsfsce10.2.0.12-x86_64.tar.gz /tmp
	cd /tmp && tar xvfz lsfsce10.2.0.12-x86_64.tar.gz && \
        cd lsfsce10.2.0.12-x86_64 && cd lsf && \
        tar xvfz lsf10.1_lsfinstall_linux_x86_64.tar.Z 
fi



groupadd -g 6201 lsfadmin
useradd lsfadmin -u 6201 -m -g lsfadmin -s /bin/bash
sudo -u lsfadmin bash -l -c "ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa; cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"

HOSTNAME=$( hostname )

## Prerpare install template 
cat <<EOF > /tmp/install.config
LSF_TOP="/opt/lsf" 
LSF_ADMINS="lsfadmin" 
LSF_CLUSTER_NAME="docker" 
LSF_MASTER_LIST=$HOSTNAME 
LSF_TARDIR="/tmp/lsfsce10.2.0.12-x86_64/lsf/" 
CONFIGURATION_TEMPLATE="DEFAULT"
EOF

apt-get -y install default-jre ed 

## Install LSFCE 
cd /tmp/lsfsce10.2.0.12-x86_64/lsf/lsf10.1_lsfinstall && echo "1" | ./lsfinstall -f /tmp/install.config 
rm -rf /tmp/lsf*

#Remapping LIM_PORT to avoid clashes with AGE
sed -i 's/7868/7869/' /opt/lsf/conf/lsf.conf

if ! [ -f ~/.ssh/id_rsa ]; then 
   ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
   cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
fi

if ! ( grep "/opt/lsf" /etc/exports ); then 
   grep slurm /etc/exports | sed 's#/opt/slurm#/opt/lsf#' | sudo tee -a /etc/exports
exportfs -ar
fi

if ! ( grep /opt/lsf/conf/profile.lsf /etc/profile ); then 
   echo "source /opt/lsf/conf/profile.lsf" >> /etc/profile
fi

source /opt/lsf/conf/profile.lsf

cat << EOF > /etc/lsf.sudoers
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=/opt/lsf/10.1/linux2.6-glibc2.3-x86_64/etc
EOF

chmod 0600 /etc/lsf.sudoers

chmod u+s /opt/lsf/10.1/linux2.6-glibc2.3-x86_64/bin/bctrld 

myip=`ifconfig eth0 | grep "inet " | awk '{print $2}'`
echo "$myip `hostname`" > /opt/lsf/conf/hosts

lsf_daemons start
