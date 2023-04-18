#!/bin/bash

# Install and configure R
apt-get update -y
apt-get install -y gdebi-core
apt-get install -y openjdk-11-jdk
apt-get install -y libfreetype6-dev libpng-dev libtiff5-dev
aws s3 cp s3://S3_BUCKETNAME/run.R /tmp

for R_VERSION in "$@" 
do
  echo "xxx R_VERSION : ${R_VERSION}"
  curl -O https://cdn.rstudio.com/r/ubuntu-2004/pkgs/r-${R_VERSION}_1_amd64.deb
  gdebi -n r-${R_VERSION}_1_amd64.deb
  dpkg --info r-${R_VERSION}_1_amd64.deb | grep " Depends" | cut -d ":" -f 2 > /opt/R/$R_VERSION/.depends
  rm -f r-${R_VERSION}_1_amd64.deb
  export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
  /opt/R/$R_VERSION/bin/R CMD javareconf 
done

for R_VERSION in "$@"
do
  /opt/R/$R_VERSION/bin/Rscript /tmp/run.R >& /var/log/r-packages-install-$R_VERSION.log &
done


### Install Python  -------------------------------------------------------------#

PYTHON_VERSION=3.8.10
curl -O https://cdn.rstudio.com/python/ubuntu-2004/pkgs/python-${PYTHON_VERSION}_1_amd64.deb && \
    apt-get update && gdebi -n python-${PYTHON_VERSION}_1_amd64.deb && \
    dpkg --info python-${PYTHON_VERSION}_1_amd64.deb | grep " Depends" | cut -d ":" -f 2 > /opt/python/$PYTHON_VERSION/.depends
    apt clean all && rm -rf /var/cache/apt && rm -f python-${PYTHON_VERSION}_1_amd64.deb

/opt/python/${PYTHON_VERSION}/bin/pip install \
    jupyter \
    jupyterlab \
    workbench_jupyterlab \
    rsp_jupyter \
    rsconnect_jupyter \
    rsconnect_python && \
/opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-serverextension enable --sys-prefix --py rsconnect_jupyter &


PYTHON_VERSION_ALT=3.9.5
curl -O https://cdn.rstudio.com/python/ubuntu-2004/pkgs/python-${PYTHON_VERSION_ALT}_1_amd64.deb && \
    apt-get update && gdebi -n python-${PYTHON_VERSION_ALT}_1_amd64.deb && \
    dpkg --info python-${PYTHON_VERSION_ALT}_1_amd64.deb | grep " Depends" | cut -d ":" -f 2 > /opt/python/$PYTHON_VERSION_ALT/.depends
    apt clean all && rm -rf /var/cache/apt && rm -f python-${PYTHON_VERSION_ALT}_1_amd64.deb

/opt/python/${PYTHON_VERSION_ALT}/bin/pip install \
    jupyter \
    jupyterlab \
    workbench_jupyterlab \
    rsp_jupyter \
    rsconnect_jupyter \
    rsconnect_python && \
/opt/python/${PYTHON_VERSION_ALT}/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION_ALT}/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION_ALT}/bin/jupyter-nbextension install --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION_ALT}/bin/jupyter-nbextension enable --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION_ALT}/bin/jupyter-serverextension enable --sys-prefix --py rsconnect_jupyter &




# prepare renv package cache 
sudo mkdir -p /scratch/renv
cat << EOF > /tmp/acl
user::rwx
group::rwx
mask::rwx
other::rwx
default:user::rwx
default:group::rwx
default:mask::rwx
default:other::rwx
EOF

setfacl -R --set-file=/tmp/acl /scratch/renv


# Install RSWB
groupadd --system --gid 900 rstudio-server
useradd -s /bin/bash -m --system --gid rstudio-server --uid 900 rstudio-server
RSWB_VER=PWB_VER
curl -O https://s3.amazonaws.com/rstudio-ide-build/server/bionic/amd64/rstudio-workbench-${RSWB_VER}-amd64.deb 
gdebi -n rstudio-workbench-${RSWB_VER}-amd64.deb
rm -f rstudio-workbench-${RSWB_VER}-amd64.deb

configdir="/opt/rstudio/etc/rstudio"
for i in server launcher 
do 
mkdir -p /etc/systemd/system/rstudio-$i.service.d
mkdir -p /opt/rstudio/etc/rstudio
cat <<EOF > /etc/systemd/system/rstudio-$i.service.d/override.conf
[Service]
Environment="RSTUDIO_CONFIG_DIR=$configdir"
EOF
done

# Install launcher keys
apt-get update && apt-get install -y uuid && \
    apt clean all && \
    rm -rf /var/cache/apt


echo `uuid` > $configdir/secure-cookie-key && \
    chown rstudio-server:rstudio-server \
            $configdir/secure-cookie-key && \
    chmod 0600 $configdir/secure-cookie-key

openssl genpkey -algorithm RSA \
            -out $configdir/launcher.pem \
            -pkeyopt rsa_keygen_bits:2048 && \
    chown rstudio-server:rstudio-server \
            $configdir/launcher.pem && \
    chmod 0600 $configdir/launcher.pem

openssl rsa -in $configdir/launcher.pem \
            -pubout > $configdir/launcher.pub && \
    chown rstudio-server:rstudio-server \
            $configdir/launcher.pub


# Add sample user 
groupadd --system --gid 8787 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 8787 rstudio

echo -e "rstudio\nrstudio" | passwd rstudio

cat  > /home/rstudio/.Rprofile << EOF
#set SLURM binaries PATH so that RSW Launcher jobs work
slurm_bin_path<-"/opt/slurm/bin"

curr_path<-strsplit(Sys.getenv("PATH"),":")[[1]]

if (!(slurm_bin_path %in% curr_path)) {
  if (length(curr_path) == 0) {
     Sys.setenv(PATH = slurm_bin_path)
  } else {
     Sys.setenv(PATH = paste0(Sys.getenv("PATH"),":",slurm_bin_path))
}

}

options(
    clustermq.scheduler = "slurm",
    clustermq.template = "~/slurm.tmpl" 
)
EOF

cat > /home/rstudio/slurm.tmpl << EOF
#!/bin/bash -l

# File: slurm.tmpl
# Template for using clustermq against a SLURM backend

#SBATCH --job-name={{ job_name }}
#SBATCH --error={{ log_file | /dev/null }}
#SBATCH --mem-per-cpu={{ memory | 1024 }}
#SBATCH --array=1-{{ n_jobs }}
#SBATCH --cpus-per-task={{ cores | 1 }}


export OMP_NUM_THREADS={{ cores | 1 }}
CMQ_AUTH={{ auth }} ${R_HOME}/bin/R --no-save --no-restore -e 'clustermq:::worker("{{ master }}")'
EOF

chown rstudio:rstudio /home/rstudio/{.Rprofile,slurm.tmpl}


# Add SLURM integration 
myip=`curl http://checkip.amazonaws.com`

mkdir -p /opt/rstudio/shared-storage

cat > $configdir/launcher-env << EOF
RSTUDIO_DISABLE_PACKAGE_INSTALL_PROMPT=yes
SLURM_CONF=/opt/slurm/etc/slurm.conf
EOF
 
cat > $configdir/rserver.conf << EOF
# Shared storage
server-shared-storage-path=/opt/rstudio/shared-storage

# Launcher Config
launcher-address=127.0.0.1
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=Slurm
launcher-sessions-callback-address=http://${myip}:8787

# Disable R Versions scanning
#r-versions-scan=0

# Location of r-versions JSON file 
r-versions-path=/opt/rstudio/shared-storage/r-versions

auth-pam-sessions-enabled=1
auth-pam-sessions-use-password=1
EOF

cat > $configdir/launcher.conf<<EOF
[server]
address=127.0.0.1
port=5559
server-user=rstudio-server
admin-group=rstudio-server
authorization-enabled=1
thread-pool-size=4
enable-debug-logging=1

[cluster]
name=Slurm
type=Slurm

#[cluster]
#name=Local
#type=Local

EOF

#cat > $configdir/launcher.slurm.profiles.conf<<EOF 
#[*]
#default-cpus=1
#default-mem-mb=512
##max-cpus=2
#max-mem-mb=1024
#EOF

cat > $configdir/launcher.slurm.resources.conf<<EOF
[small]
name = "Small (1 cpu, 4 GB mem)"
cpus=1
mem-mb=4096
[medium]
name = "Medium (4 cpu, 16 GB mem)"
cpus=4
mem-mb=16384
[large]
name = "Large (8 cpu, 32 GB mem)"
cpus=8
mem-mb=32768
[xlarge]
name = "Extra Large (16 cpu, 64 GB mem)"
cpus=16
mem-mb=65536
EOF

cat > $configdir/launcher.slurm.conf << EOF 
# Enable debugging
enable-debug-logging=1

# Basic configuration
slurm-service-user=slurm
slurm-bin-path=/opt/slurm/bin

# Singularity specifics
#constraints=Container=singularity-container

# GPU specifics
enable-gpus=1
gpu-types=v100

EOF

cat > $configdir/jupyter.conf << EOF
jupyter-exe=/opt/python/$PYTHON_VERSION/bin/jupyter
notebooks-enabled=1
labs-enabled=1
EOF

#remove default R version (too old)
apt remove -y r-base r-base-core r-base-dev r-base-html r-doc-html

systemctl daemon-reload
rstudio-server stop
rstudio-launcher stop

rstudio-launcher start
rstudio-server start

# Install VSCode based on the PWB version.
if ( rstudio-server | grep configure-vs-code ); then rstudio-server configure-vs-code ; rstudio-server install-vs-code-ext; else rstudio-server install-vs-code /opt/rstudio/vscode/; fi
  
cat > $configdir/vscode.conf << EOF
enabled=1
exe=/usr/lib/rstudio-server/bin/code-server/bin/code-server
args=--verbose --host=0.0.0.0 --extensions-dir=/opt/rstudio/code-server 
EOF
 
if [ -f /etc/rstudio/vscode-user-settings.json ]; then 
   cp /etc/rstudio/vscode-user-settings.json $configdir
fi

for extension in quarto.quarto \
	REditorSupport.r@2.6.1 \
	ms-python.python@2022.10.1 \
	/usr/lib/rstudio-server/bin/vscode-workbench-ext/rstudio-workbench.vsix  
do
   /usr/lib/rstudio-server/bin/code-server/bin/code-server --extensions-dir=/opt/rstudio/code-server --install-extension $extension
done

rm -f /etc/rstudio

systemctl restart slurmctld

# Packages for R packages
apt-get install -y libzmq5  libglpk40 libnode-dev

# add GPU cgroup support
echo "ConstrainDevices=yes" >> /opt/slurm/etc/cgroup.conf

systemctl restart slurmctld 

#add support for Lua Job Submit plugin 

apt-get install -y liblua5.3-dev 
export SLURM_VERSION=`/opt/slurm/bin/sinfo -V | awk '{print $2}' `
tmpdir=`mktemp -d`
pushd $tmpdir
  git clone --depth 1 -b slurm-${SLURM_VERSION//./-}-1 https://github.com/SchedMD/slurm.git
  pushd slurm
    ./configure
    pushd src/lua
      make 
    popd
    pushd src/plugins/job_submit/lua
      make 
      cp .libs/job_submit_lua.so /opt/slurm/lib/slurm/job_submit_lua.so
    popd
  popd
popd
rm -rf $tmpdir
echo "JobSubmitPlugins=lua" >> /opt/slurm/etc/slurm.conf
aws s3 cp s3://S3_BUCKETNAME/job_submit.lua /opt/slurm/etc/
systemctl restart slurmctld


# Prometheus

mkdir /opt/prometheus
PROM_VER=2.43.0

wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz
tar xvfz prometheus-${PROM_VER}.linux-amd64.tar.gz -C /opt/prometheus
rm -f prometheus-${PROM_VER}.linux-amd64.tar.gz

PROM_NODE_EX_VER="1.5.0"
wget https://github.com/prometheus/node_exporter/releases/download/v${PROM_NODE_EX_VER}/node_exporter-${PROM_NODE_EX_VER}.linux-amd64.tar.gz
tar xvfz node_exporter-${PROM_NODE_EX_VER}.linux-amd64.tar.gz -C /opt/prometheus/
rm -f node_exporter-${PROM_NODE_EX_VER}.linux-amd64.tar.gz

/opt/prometheus/node_exporter-${PROM_NODE_EX_VER}.linux-amd64/node_exporter &

cat << EOF > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
- job_name: node
  static_configs:
  - targets: ['XXX']
EOF

prom_targets=`/opt/slurm/bin/sinfo -N  -h  | awk '{print $1}' | tr '\n' ' ' | rev | sed "s# #','#2g" | rev | sed "s#',#:9100',#g" | sed 's/ /:9100/'`

sed -i "s/XXX/localhost:9100','$prom_targets/" /opt/prometheus/prometheus.yml
pushd /opt/prometheus
/opt/prometheus/prometheus-${PROM_VER}.linux-amd64/prometheus &
popd


mkdir -p /opt/code-server

grep slurm /etc/exports | sed 's/slurm/R/' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's/slurm/python/' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's/slurm/rstudio/' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's/slurm/code-server/' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's#/opt/slurm#/usr/lib/rstudio-server#' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's#/opt/slurm#/scratch#' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's/slurm/prometheus/' | sudo tee -a /etc/exports
exportfs -ar 

mount -a

rm -rf /etc/profile.d/modules.sh


exit 0 
