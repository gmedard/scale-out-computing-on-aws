#!/bin/bash -ex
# Configure the proxy server
# This is called by the instance UserData the first time it boots.

set -ex

source /etc/environment

yum update -y --security

# Install SSM agent
if yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm; then
    if ! systemctl is-enabled amazon-ssm-agent; then
        systemctl enable amazon-ssm-agent
    fi
    systemctl restart amazon-ssm-agent
fi

SERVER_IP=$(hostname -I | tr -d '[:space:]')
SERVER_HOSTNAME=$(hostname)
SERVER_HOSTNAME_ALT=$(echo $SERVER_HOSTNAME | cut -d. -f1)
echo $SERVER_IP $SERVER_HOSTNAME $SERVER_HOSTNAME_ALT >> /etc/hosts

# Add a DNS entry to Route53 for the proxy
rm -f /tmp/route53.json
cat <<EOF >>/tmp/route53.json
{
    "Comment": "Update proxy record",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "proxy.${SOCA_DOMAIN}",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [{"Value": "${SERVER_IP}"}]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $SOCA_HOSTED_ZONE_ID --change-batch file:///tmp/route53.json

# Disable StrictHostKeyChecking
echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

# Configure NTP
yum remove -y ntp
yum install -y chrony
mv /etc/chrony.conf  /etc/chrony.conf.original
echo -e """
# use the local instance NTP service, if available
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4

# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
# !!! [BEGIN] SOCA REQUIREMENT
# You will need to open UDP egress traffic on your security group if you want to enable public pool
#pool 2.amazon.pool.ntp.org iburst
# !!! [END] SOCA REQUIREMENT
# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys

# Specify directory for log files.
logdir /var/log/chrony

# save data between restarts for fast re-load
dumponexit
dumpdir /var/run/chrony
""" > /etc/chrony.conf
systemctl enable chronyd

# Disable ulimit
echo -e  "
* hard memlock unlimited
* soft memlock unlimited
" > /etc/security/limits.conf

# Install squid
amazon-linux-extras install -y squid4
systemctl enable squid
# Configure proxy
aws s3 cp --recursive s3://${SOCA_INSTALL_BUCKET}/${SOCA_INSTALL_BUCKET_FOLDER}/proxy/etc/squid /etc/squid
systemctl restart squid
