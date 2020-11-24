#!/bin/bash -xe

if [ $# -lt 4 ]
  then
    echo "usage: $0 S3Bucket S3InstallFolder UserName UserPassword"
    exit 1
fi

source /etc/environment
source /root/config.cfg
source /etc/profile.d/proxy.sh

# Signal Cloudformation if the instance creates successfully or not
function on_exit {
    /opt/aws/bin/cfn-signal -e $? --stack ${SOCA_CLOUDFORMATION_STACK} --resource SchedulerEC2Host --region ${AWS_DEFAULT_REGION} || true
}
trap on_exit EXIT

function info {
    echo "INFO: $(date +'%m/%d/%Y %H:%M:%S'): $1"
}

function error {
    echo "ERROR: $(date +'%m/%d/%Y %H:%M:%S'): $1"
}

# First flush the current crontab to prevent this script from running on the next reboot
crontab -r || true

# Copy  Aligo scripts file structure
AWS=$(which aws)
# Retrieve SOCA configuration under soca.tar.gz and extract it on /apps/
$AWS s3 cp s3://$SOCA_INSTALL_BUCKET/$SOCA_INSTALL_BUCKET_FOLDER/soca.tar.gz /root
mkdir -p /apps/soca/$SOCA_CONFIGURATION
tar -xvf /root/soca.tar.gz -C /apps/soca/$SOCA_CONFIGURATION --no-same-owner

mkdir -p /apps/soca/$SOCA_CONFIGURATION/cluster_manager/logs
chmod +x /apps/soca/$SOCA_CONFIGURATION/cluster_manager/aligoqstat.py

# Generate default queue_mapping file based on default AMI choosen by customer
if [ ! -e /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml ]; then
cat <<EOT >> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml
# This manage automatic provisioning for your queues
# These are default values. Users can override them at job submission
# https://awslabs.github.io/scale-out-computing-on-aws/tutorials/create-your-own-queue/
queue_type:
  compute:
    queues: ["high", "normal", "low"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI" # Required
    instance_type: "c5.large" # Required
    ht_support: "false"
    root_size: "10"
    #scratch_size: "100"
    #scratch_iops: "3600"
    #efa_support: "false"
    # .. Refer to the doc for more supported parameters
  desktop:
    queues: ["desktop"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI" # Required
    instance_type: "c5.large"  # Required
    ht_support: "false"
    root_size: "10"
    # .. Refer to the doc for more supported parameters
  test:
    queues: ["test"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI"  # Required
    instance_type: "c5.large"  # Required
    ht_support: "false"
    root_size: "10"
    #spot_price: "auto"
    #placement_group: "false"
    # .. Refer to the doc for more supported parameters
EOT
fi

# Generate 10 years internal SSL certificate for Soca Web UI
cd /apps/soca/$SOCA_CONFIGURATION/cluster_web_ui
if ! [ -e cert.crt ]; then
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=California/L=Sunnyvale/CN=internal.soca.webui.cert" \
    -keyout cert.key -out cert.crt
fi

# Wait for PBS to restart
sleep 60

## Update PBS Hooks with the current script location
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_acls.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_instance_types.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_restricted_parameters.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_licenses_mapping.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_project_budget.py

sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/job_notifications.py

# Create Default PBS hooks
if [ ! -e /var/lib/cloud/instance/sem/pbs_hooks_created ]; then
qmgr -c "create hook check_queue_acls event=queuejob"
qmgr -c "import hook check_queue_acls application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_acls.py"
qmgr -c "create hook check_queue_instance_types event=queuejob"
qmgr -c "import hook check_queue_instance_types application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_instance_types.py"
qmgr -c "create hook check_queue_restricted_parameters event=queuejob"
qmgr -c "import hook check_queue_restricted_parameters application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_restricted_parameters.py"
qmgr -c "create hook check_licenses_mapping event=queuejob"
qmgr -c "import hook check_licenses_mapping application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_licenses_mapping.py"

# Reload config
systemctl restart pbs

  touch /var/lib/cloud/instance/sem/pbs_hooks_created
fi

# Create crontabs
echo "
## Cluster Analytics
* * * * * source /etc/environment; /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/cluster_nodes_tracking.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/cluster_nodes_tracking.log 2>&1
@hourly source /etc/environment; /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/job_tracking.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/job_tracking.log 2>&1

## Cluster Log Management
@daily  source /etc/environment; /bin/bash /apps/soca/$SOCA_CONFIGURATION/cluster_logs_management/send_logs_s3.sh >>/apps/soca/$SOCA_CONFIGURATION/cluster_logs_management/send_logs_s3.log 2>&1

## Cluster Management
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3  /apps/soca/$SOCA_CONFIGURATION/cluster_manager/nodes_manager.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/nodes_manager.py.log 2>&1

## Cluster Web UI
### Restart UI at reboot
@reboot /apps/soca/$SOCA_CONFIGURATION/cluster_web_ui/socawebui.sh start

## Automatic Host Provisioning
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t compute &> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/logs/dispatcher.compute.log
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t desktop &> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/logs/dispatcher.desktop.log
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t test &> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/logs/dispatcher.test.log

# Add/Remove DCV hosts and configure ALB
*/3 * * * * source /etc/environment; /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dcv_alb_manager.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dcv_alb_manager.py.log 2>&1
" | crontab -

# Start Web UI
chmod +x /apps/soca/$SOCA_CONFIGURATION/cluster_web_ui/socawebui.sh
/apps/soca/$SOCA_CONFIGURATION/cluster_web_ui/socawebui.sh stop
/apps/soca/$SOCA_CONFIGURATION/cluster_web_ui/socawebui.sh start

# Re-enable access
if [ "$SOCA_BASE_OS" == "amazonlinux2" ] || [ "$SOCA_BASE_OS" == "rhel7" ];
     then
     usermod --shell /bin/bash ec2-user
fi

if [ "$SOCA_BASE_OS" == "centos7" ];
     then
     usermod --shell /bin/bash centos
fi

# Check if the Cluster is fully operational

# Verify PBS
if [ -z "$(pgrep pbs)" ]
    then
    echo -e "
    /!\ /!\ /!\ /!\ /!\ /!\ /!\ /!\
    ERROR WHILE CREATING ALIGO HPC
    *******************************
    PBS SERVICE NOT DETECTED
    ********************************
    The USER-DATA did not run properly
    Please look for any errors on /var/log/message | grep cloud-init
    " > /etc/motd
    exit 1
fi

# Verify OpenLDAP
if [ -z "$(pgrep slapd)" ]
    then
    echo -e "
    /!\ /!\ /!\ /!\ /!\ /!\ /!\ /!\
    ERROR WHILE CREATING ALIGO HPC
    *******************************
    LDAP SERVICE NOT DETECTED
    ********************************
    The USER-DATA did not run properly
    Please look for any errors on /var/log/message | grep cloud-init
    " > /etc/motd
    exit 1
fi
# Verify SSSD
if [ -z "$(pgrep sssd)" ]
    then
    echo -e "
    /!\ /!\ /!\ /!\ /!\ /!\ /!\ /!\
    ERROR WHILE CREATING ALIGO HPC
    *******************************
    SSSD SERVICE NOT DETECTED
    ********************************
    The USER-DATA did not run properly
    Please look for any errors on /var/log/message | grep cloud-init
    " > /etc/motd
    exit 1
fi

# Cluster is ready
amazon-linux-extras install -y epel
yum -y install figlet
figlet -f slant "SOCA Scheduler" > /etc/motd
echo -e "Cluster: $SOCA_CONFIGURATION
> source /etc/environment to load SOCA paths
" >> /etc/motd

# Signal CloudFormation to continue
/opt/aws/bin/cfn-signal -e 0 --stack ${SOCA_CLOUDFORMATION_STACK} --resource SchedulerEC2Host --region ${AWS_DEFAULT_REGION} || true

# Move this last because it depends on the Configuration stack which is deployed last.
if [ ! -e /var/lib/cloud/instance/sem/user_created ]; then
  # When using custom AMI, the scheduler is fully operational even before SecretManager is ready. LDAP_Manager has a dependency on SecretManager so we have to wait a little bit (or create the user manually once secretmanager is available)
  MAX_ATTEMPT=10
  CURRENT_ATTEMPT=0
  # Create default LDAP user

  sanitized_username="$3"
  sanitized_password="$4"

  if ! id [ ! sanitized_username; then
    until `/apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/ldap_manager.py add-user -u $sanitized_username -p $sanitized_password --admin >> /dev/null 2>&1`
    do
      info "Unable to add new LDAP user as command failed (secret manager not ready?) Waiting 3 minutes ..."
      if [[ $CURRENT_ATTEMPT -ge $MAX_ATTEMPT ]];
      then
        error "Unable to create LDAP user after 5 attempts, try to run the command manually: /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/ldap_manager.py add-user -u '$3' -p '$4' --admin"
        exit 1
      fi
      sleep 180
      ((CURRENT_ATTEMPT=CURRENT_ATTEMPT+1))
    done
  fi

  touch /var/lib/cloud/instance/sem/user_created
fi

if [ ! -e /var/lib/cloud/instance/sem/open_mpi_installed ]; then
# Install OpenMPI
# This will take a while and is not system blocking, so adding at the end of the install process
mkdir -p /apps/soca/$SOCA_CONFIGURATION/openmpi/installer
cd /apps/soca/$SOCA_CONFIGURATION/openmpi/installer

wget $OPENMPI_URL
if [[ $(md5sum $OPENMPI_TGZ | awk '{print $1}') != $OPENMPI_HASH ]];  then
    echo -e "FATAL ERROR: Checksum for OpenMPI failed. File may be compromised." > /etc/motd
    exit 1
fi

tar xvf $OPENMPI_TGZ
cd openmpi-$OPENMPI_VERSION
./configure --prefix=/apps/soca/$SOCA_CONFIGURATION/openmpi/$OPENMPI_VERSION
make
make install

  touch /var/lib/cloud/instance/sem/open_mpi_installed
fi

# Clean directories
rm -rf /root/pbspro-18.1.4*
# Don't remove these so can rerun scripts if necessary
#rm -rf /root/*.sh
#rm -rf /root/config.cfg
