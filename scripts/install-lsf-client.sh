#!/bin/bash

if ! ( grep /opt/lsf /etc/fstab ); then 
    grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/lsf#g'  >> /etc/fstab
    mount /opt/lsf
fi

groupadd -g 6201 lsfadmin
useradd lsfadmin -u 6201 -g lsfadmin -s /bin/bash

if ! ( grep /opt/lsf/conf/profile.lsf /etc/profile ); then 
   echo "source /opt/lsf/conf/profile.lsf" >> /etc/profile
fi

source /etc/profile

myip=`ifconfig eth0 | grep "inet " | awk '{print $2}'`
hostname=`hostname`
hostentry="$myip $hostname"
if  ( grep $hostname /opt/lsf/conf/hosts ); then 
    sed -i "s/.*${hostname}/$hostentry/" 
else   
    echo "$myip `hostname`" >> /opt/lsf/conf/hosts
fi

if ! ( grep $hostname /opt/lsf/conf/lsf.cluster.docker ); then 
    sed -i "/^End     Host.*/i $hostname !   !   1   (linux)/" /opt/lsf/conf/lsf.cluster.docker
fi

bctrld start lim 
bctrld start res
bctrld start sbd

