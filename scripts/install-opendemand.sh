yum install -y centos-release-scl
yum install -y https://yum.osc.edu/ondemand/2.0/ondemand-release-web-2.0-1.noarch.rpm
yum install -y ondemand ondemand-dex

iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

groupadd ood
useradd -d /home/ood -g ood -k /etc/skel -m ood
sudo -u ood bash -l -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
sudo -u ood bash -l -c "cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && chmod 0600 ~/.ssh/authorized_keys" 

pubhost=$( host `curl ifconfig.me`  | awk '{print $5}' | sed 's/\.$//' )

awsip=`hostname -I | awk '{print $1}'`

sed -i "s/$awsip/& $pubhost/" /etc/hosts

systemctl start httpd24-httpd
systemctl enable httpd24-httpd

systemctl start ondemand-dex
systemctl enable ondemand-dex

mkdir -p /etc/ood/config/clusters.d

cat <<EOF > /etc/ood/config/clusters.d/AWS.yml
v2:
  metadata:
    title: "AWS ParallelCluster"
  login:
    host: "$pubhost"
  job:
    adapter: "slurm"
    bin: "/opt/slurm/bin"
    conf: "/opt/slurm/etc/slurm.conf"
EOF

#compute

yum install -y https://sourceforge.net/projects/turbovnc/files/2.2.7/turbovnc-2.2.7.x86_64.rpm
yum install -y nmap


