#!/bin/bash -ex

if [ $# -lt 1 ]
  then
    echo "usage: $0 CONFIG-FILE"
    exit 1
fi

config_file=$1
if [ ! -e $config_file ]; then
    config_file=/root/cw-agent-config-computeNode.json
fi

scriptdir=$(dirname $(readlink -f $0))
BASE_OS=$($scriptdir/get-base-os.sh)

arch=$(uname -i)

if [ $BASE_OS == "amazonlinux2" ]; then
    yum -y install amazon-cloudwatch-agent
else
    # This is really weird, but amd64 is for both x86_64 and amd64.
    if [ $BASE_OS == "centos7" ]; then
        aws s3 cp s3://amazoncloudwatch-agent-{{Region}}/centos/amd64/latest/amazon-cloudwatch-agent.rpm .
    elif [ $BASE_OS == "rhel7" ]; then
        aws s3 cp s3://amazoncloudwatch-agent-{{Region}}/redhat/amd64/latest/amazon-cloudwatch-agent.rpm .
    else
        echo "error: Unsupported OS $BASE_OS"
        exit 1
    fi
    rpm -U ./amazon-cloudwatch-agent.rpm
    rm amazon-cloudwatch-agent.rpm
fi

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a fetch-config -c file:$config_file

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a start
