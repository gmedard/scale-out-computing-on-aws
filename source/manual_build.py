#!/usr/bin/env python3

import datetime as dt
from datetime import datetime
import fileinput
import os
import random
import re
import shutil
import string
import sys
import argparse
from shutil import make_archive, copy, copytree
from time import sleep

def upload_objects(s3, bucket_name, s3_prefix, directory_name):
    try:
        my_bucket = s3.Bucket(bucket_name)
        for path, subdirs, files in os.walk(directory_name):
            path = path.replace("\\","/")
            directory = path.replace(directory_name,"")
            for file in files:
                print("%s[+] Uploading %s to s3://%s/%s%s%s" % (fg('green'), os.path.join(path, file), bucket_name, s3_prefix, directory+'/'+file, attr('reset')))
                my_bucket.upload_file(os.path.join(path, file), s3_prefix+directory+'/'+file)

    except Exception as err:
        print(err)


def get_input(prompt):
    if sys.version_info[0] >= 3:
        response = input(prompt)
    else:
        #Python 2
        response = raw_input(prompt)
    return response

if __name__ == "__main__":
    try:
        from colored import fg, bg, attr
        import boto3
        from botocore.client import ClientError
        from botocore.exceptions import ProfileNotFound
    except ImportError:
        print(" > You must have 'colored' and 'boto3' installed. Run 'pip install boto3 colored'")
        exit(1)

    parser = argparse.ArgumentParser(description='Build & Upload SOCA CloudFormation resources.')
    parser.add_argument('--profile', '-p', type=str, help='AWS CLI profile to use. See https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html')
    parser.add_argument('--region', '-r', type=str, help='AWS region to use. If not specified will be prompted.')
    parser.add_argument('--bucket', '-b', type=str, help='S3 Bucket to use. If not specified will be prompted.')
    parser.add_argument('--stack-name', '-s', type=str, help='Stack name to deploy in quick create link.')
    parser.add_argument('--client-ip', type=str, help='CIDR that can access scheduler.')
    parser.add_argument('--prefix-list-id', '--pl', type=str, help='Prefix list for ingress.')
    parser.add_argument('--ssh-keypair', type=str, help='SSH keypair.')
    parser.add_argument('--username', type=str, help='Username')
    parser.add_argument('--id', type=str, help='Unique id for the s3 bucket folder. Use to update existing build.')
    parser.add_argument('--create-change-set', action='store_true', default=False, help='Create CloudFormation changeset.')
    parser.add_argument('--update', action='store_true', default=False, help='Create CloudFormation changeset and execute it.')
    args = parser.parse_args()

    print("====== Parameters ======\n")
    if not args.region:
        region = get_input(" > Please enter the AWS region you'd like to build SOCA in: ")
    else:
        region = args.region
    if not args.bucket:
        bucket = get_input(" > Please enter the name of an S3 bucket you own: ")
    else:
        bucket = args.bucket

    if args.client_ip:
        client_ip_re = r'(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})'
        if not re.match(client_ip_re, args.client_ip):
            print("Invalid --client-ip {}. Must match {}".format(args.client_ip, client_ip_re))
            exit(1)

    s3_bucket_exists = False
    try:
        print(" > Validating you can have access to that bucket...")
        if args.profile:
            try:
                session = boto3.session.Session(profile_name=args.profile)
                s3 = session.resource('s3', region_name=region)
            except ProfileNotFound:
                print(" > Profile %s not found. Check ~/.aws/credentials file." % args.profile)
                exit(1)
        else:
            s3 = boto3.resource('s3', region_name=region)
        s3.meta.client.head_bucket(Bucket=bucket)
        s3_bucket_exists = True
    except ClientError as e:
        print(" > The bucket "+ bucket + " does not exist or you have no access.")
        print(e)
        print(" > Building locally but not uploading to S3")

    build_path = os.path.dirname(os.path.realpath(__file__))
    os.chdir(build_path)
    # Make sure build ID is > 3 chars and does not start with a number
    if args.id:
        unique_id = args.id
    else:
        unique_id = ''.join(random.choice(string.ascii_lowercase) + random.choice(string.digits) for i in range(2))
    build_folder = 'dist/' + unique_id
    if os.path.exists(build_folder):
        shutil.rmtree(build_folder)
    output_prefix = "soca-installer-" + unique_id  # prefix for the output artifact
    print("====== SOCA Build ======\n")
    print(" > Generated unique ID for build: " + unique_id)
    print(" > Creating temporary build folder ... ")
    print(" > Copying required files ... ")
    targets = ['proxy', 'scripts', 'templates', 'README.txt', 'scale-out-computing-on-aws.template', 'install-with-existing-resources.template']
    for target in targets:
        if os.path.isdir(target):
            copytree(target, build_folder + '/' + target)
        else:
            copy(target, build_folder + '/' + target)
    make_archive(build_folder + '/soca', 'gztar', 'soca')

    # Replace Placeholder
    for line in fileinput.input([build_folder + '/scale-out-computing-on-aws.template', build_folder + '/install-with-existing-resources.template'], inplace=True):
        print(line.replace('%%BUCKET_NAME%%', 'your-s3-bucket-name-here').replace('%%SOLUTION_NAME%%/%%VERSION%%', 'your-s3-folder-name-here').replace('\n', ''))

    print(" > Creating archive for build id: " + unique_id)
    make_archive('dist/' + output_prefix, 'gztar', build_folder)

    if s3_bucket_exists:
        print("====== Upload to S3 ======\n")
        print(" > Uploading required files ... ")
        upload_objects(s3, bucket, output_prefix, build_path + "/" + build_folder)

        # CloudFormation Template URL
        template_url = "https://%s.s3.amazonaws.com/%s/scale-out-computing-on-aws.template" % (bucket, output_prefix)

        params = ''
        if args.stack_name:
            params += '&StackName=' + args.stack_name

        params += '&param_S3InstallBucket=%s&param_S3InstallFolder=%s' % (bucket, output_prefix)

        if args.client_ip:
            params += '&param_ClientIp=' + args.client_ip

        if args.prefix_list_id:
            params += '&param_PrefixListId=' + args.prefix_list_id

        if args.ssh_keypair:
            params += '&param_SSHKeyPair=' + args.ssh_keypair

        if args.username:
            params += '&param_UserName=' + args.username
        
        print("\n====== Upload COMPLETE ======")
        print("\ntemplate URL: " + template_url)
        print("\n====== Installation Instructions ======")
        print("1. Click on the following link:")
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s%s%s" % (fg('light_blue'), region, template_url, params, attr('reset')))
        print("2. The 'Install Location' parameters are pre-filled for you, fill out the rest of the parameters.")
        if args.id:
            print("\nUpdated template: {}".format(template_url))
        
        if args.create_change_set or args.update:
            now = datetime.now(dt.timezone.utc)
            changeSetName = '{}-update-{}'.format(args.stack_name, now.strftime('%y%m%d%H%M%S'))
            cfn_client = boto3.client('cloudformation')
            parameters = [
                {'ParameterKey': 'BaseOS', 'UsePreviousValue': True},
                {'ParameterKey': 'CustomAMI', 'UsePreviousValue': True},
                {'ParameterKey': 'S3InstallBucket', 'ParameterValue': args.bucket},
                {'ParameterKey': 'S3InstallFolder', 'ParameterValue': output_prefix},
                {'ParameterKey': 'SchedulerInstanceType', 'UsePreviousValue': True},
                {'ParameterKey': 'UserPassword', 'UsePreviousValue': True},
                {'ParameterKey': 'VpcCidr', 'UsePreviousValue': True},
            ]
            if args.client_ip:
                parameters.append({'ParameterKey': 'ClientIp', 'ParameterValue': args.client_ip})
            else:
                parameters.append({'ParameterKey': 'ClientIp', 'UsePreviousValue': True})
            if args.prefix_list_id:
                parameters.append({'ParameterKey': 'PrefixListId', 'ParameterValue': args.prefix_list_id})
            else:
                parameters.append({'ParameterKey': 'PrefixListId', 'UsePreviousValue': True})
            if args.ssh_keypair:
                parameters.append({'ParameterKey': 'SSHKeyPair', 'ParameterValue': args.ssh_keypair})
            else:
                parameters.append({'ParameterKey': 'SSHKeyPair', 'UsePreviousValue': True})
            if args.username:
                parameters.append({'ParameterKey': 'UserName', 'ParameterValue': args.username})
            else:
                parameters.append({'ParameterKey': 'UserName', 'UsePreviousValue': True})

            if args.prefix_list_id:
                parameters.append({'ParameterKey': 'PrefixListId', 'ParameterValue': args.prefix_list_id})
            else:
                parameters.append({'ParameterKey': 'PrefixListId', 'UsePreviousValue': True})
            if args.prefix_list_id:
                parameters.append({'ParameterKey': 'PrefixListId', 'ParameterValue': args.prefix_list_id})
            else:
                parameters.append({'ParameterKey': 'PrefixListId', 'UsePreviousValue': True})
            if args.prefix_list_id:
                parameters.append({'ParameterKey': 'PrefixListId', 'ParameterValue': args.prefix_list_id})
            else:
                parameters.append({'ParameterKey': 'PrefixListId', 'UsePreviousValue': True})
            cfn_client.create_change_set(
                StackName=args.stack_name,
                TemplateURL=template_url,
                Capabilities=['CAPABILITY_IAM', 'CAPABILITY_AUTO_EXPAND'],
                ChangeSetName=changeSetName,
                Parameters=parameters,
            )
            print("\nCreated CloudFormation change set: {}".format(changeSetName))
        if args.update:
            print("\nWaiting for change set to be created")
            status = 'CREATE_PENDING'
            while status != 'CREATE_COMPLETE':
                status = cfn_client.describe_change_set(StackName=args.stack_name, ChangeSetName=changeSetName)['Status']
                sleep(1)
            print("\nExecuting {}".format(changeSetName))
            cfn_client.execute_change_set(ChangeSetName=changeSetName, StackName=args.stack_name)
    else:
        print("\n====== Installation Instructions ======")
        print("1: Create or use an existing S3 bucket on your AWS account (eg: 'mysocacluster')")
        print("2: Drag & Drop " + build_path + "/" + build_folder + " to your S3 bucket (eg: 'mysocacluster/" + build_folder + ")")
        print("3: Launch CloudFormation and use scale-out-computing-on-aws.template as base template")
        print("4: Enter your cluster information.")

    print("\n\nFor more information: https://awslabs.github.io/scale-out-computing-on-aws/install-soca-cluster/")

