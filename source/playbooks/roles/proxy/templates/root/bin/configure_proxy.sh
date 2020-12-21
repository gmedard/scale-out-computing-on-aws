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
systemctl enable chronyd
