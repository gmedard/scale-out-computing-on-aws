---
title: EC2 Image Builder
---

SOCA uses EC2 Image Builder Pipelines to automate the creation of custom AMIs.
By default it creates pipelines for four different CentOS 7 based AMIs.

* **CentOS 7 SOCA AMI**: Preinstalls the SOCA software
* **CentOS 7 SOCA Desktop**: Same as CentOS 7 SOCA AMI plus installs the DCV software for Linux Desktop instances.
* **CentOS 7 EDA AMI**: Same as CentOS 7 SOCA AMI plus installs packages required by EDA tools.
* **CentOS 7 SOCA Desktop**: Same as CentOS 7 EDA AMI plus installs the DCV software for Linux Desktop instances.

By default the pipelines are created and executed.
You can follow the *BuildUrl links in the stack outputs to get the status of the AMIs and the AMI IDs once the builds are complete.

You can also set the CloudFormation parameters so that these images are automatically
created during SOCA deployment and the AMI IDs are included in the outputs of the stack.
The risk of creating them this way at deployment is that if any images fail to build then the deployment will fail and will have to be
deleted and redeployed.
For this reason we recommend that you deploy SOCA with these parameters set to their default value of false and then update the stack with
the parameters set to true after the initial deployment successfully completes.
Or you can just follow the BuildUrls and get the IDs manually.

## Manually Running the Pipelines to Create the AMIs

You can also manually trigger the pipelines to create the AMIs.

### Running Pipelines Using the Console

Follow the *ImagePipelineUrl link in the stack outputs to go to the EC2 Image Builder pipeline.
From Actions select **Run Pipeline**.
This will trigger the pipeline and you can monitor it's progress by selecting **Images** on the left.

### Running Pipelines Using the AWS CLI

Go to the CloudFormation console and the Outputs tab of your SOCA stack.
The command to manually run the pipelines are in the outputs.

### Monitoring Pipeline Builds

Go to the EC2 Image Builder console, select **Image Pipelines**, and select a pipeline to see it's output images.
