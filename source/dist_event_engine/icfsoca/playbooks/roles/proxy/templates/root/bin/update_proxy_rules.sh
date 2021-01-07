#!/bin/bash -xe
# Updates proxy rules from S3 bucket
# Download latest rules, compare with current, update and restart proxy if there are changes.

aws s3 cp --recursive s3://${S3InstallBucket}/${S3InstallFolder}/playbooks/ /root/playbooks/
cd /root/playbooks
ansible-playbook proxy.yml -e Region={{Region}} -e Domain={{SocaDomain}} -e S3InstallBucket={{S3InstallBucket}} -e S3InstallFolder={{S3InstallFolder}} -e ClusterId={{ClusterId}} &> /root/ansible.log
