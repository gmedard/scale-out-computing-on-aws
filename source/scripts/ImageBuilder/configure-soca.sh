#!/bin/bash -x

scriptdir=$(dirname $(readlink -f $0))
scriptsdir=$(readlink -f $scriptdir/..)
socadir=$(readlink -f $scriptdir/../..)

source /etc/environment

if grep -q 'Amazon Linux release 2' /etc/system-release; then
    BASE_OS=amazonlinux2
elif grep -q 'CentOS Linux release 7' /etc/system-release; then
    BASE_OS=centos7
else
    BASE_OS=rhel7
fi
export BaseOS=$BASE_OS
echo "BaseOs=$BaseOs"

# Install pip
if ! which pip2.7; then
    echo "Installing pip2.7"
    if [ "$BaseOS" == "centos7" ] || [ "$BaseOS" == "rhel7" ]; then
        EASY_INSTALL=$(which easy_install-2.7)
        $EASY_INSTALL pip
    fi
fi
PIP=$(which pip2.7)

# awscli is installed by the aws-cli-version-2-linux component
AWS=$(which aws)

# Configure file system mounts
# Can't mount them in the public subnet
echo -e "\nConfiguring mount of $EFS_DATA at /data"
mkdir -p /data
echo "$EFS_DATA:/ /data nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab
echo -e "\nConfiguring mount of $EFS_APPS at /apps"
mkdir -p /apps
echo "$EFS_APPS:/ /apps nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab

source $scriptsdir/config.cfg
if [ "$BaseOS" == "rhel7" ]; then
    yum-config-manager --enable rhel-7-server-rhui-optional-rpms
    yum-config-manager --enable rhel-7-server-rhui-rpms
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

if yum list installed ansible &> /dev/null; then
    echo "ansible already installed"
else
    echo "Installing ansible"
    if [ $BaseOS == "amazonlinux2" ]; then
        amazon-linux-extras install -y ansible2
    else
        yum -y install ansible
    fi
fi

if ! yum install -y $(echo ${SYSTEM_PKGS[*]}) &> system_pkgs.log; then
    cat system_pkgs.log
    exit 1
fi
if ! yum install -y $(echo ${SCHEDULER_PKGS[*]}) &> scheduler_pkgs.log; then
    cat scheduler_pkgs.log
    exit 1
fi
if ! yum install -y $(echo ${OPENLDAP_SERVER_PKGS[*]}) &. openldap_server_pkgs.log; then
    cat openldap_server_pkgs.log
    exit 1
fi
if ! yum install -y $(echo ${SSSD_PKGS[*]}) &> sssd_pkgs.log; then
    cat sssd_pkgs.log
    exit 1
fi

# Install PBS Pro
cd /root
wget $OPENPBS_URL
tar zxvf $OPENPBS_TGZ
cd openpbs-$OPENPBS_VERSION
./autogen.sh
./configure --prefix=/opt/pbs
if ! make -j6 &> openpbs_build.log; then
    cat openpbs_build.log
    exit 1
fi
if ! make install -j6 &> openpbs_install.log; then
    cat openpbs_install.log
    exit 1
fi
/opt/pbs/libexec/pbs_postinstall
chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp
systemctl disable pbs

systemctl disable libvirtd.service || true
if ifconfig virbr0; then
    ip link set virbr0 down
    brctl delbr virbr0
fi
systemctl disable firewalld || true
systemctl stop firewalld || true
