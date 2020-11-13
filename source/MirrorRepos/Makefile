
ifeq ($(strip ${S3_INSTALL_BUCKET}),)
  $(error Must define S3_INSTALL_BUCKET)
endif
ifeq ($(strip ${S3_INSTALL_PREFIX}),)
  $(error Must define S3_INSTALL_PREFIX)
endif
ifneq ($(or $(findstring create,${MAKECMDGOALS}), $(findstring update,${MAKECMDGOALS})),)
  ifeq ($(strip ${STACK_NAME}),)
    $(error Must define STACK_NAME)
  endif
  ifeq ($(strip ${S3_MIRROR_REPO_BUCKET}),)
    $(error Must define S3_MIRROR_REPO_BUCKET)
  endif
  ifeq ($(strip ${S3_MIRROR_REPO_FOLDER}),)
    $(error Must define S3_MIRROR_REPO_FOLDER)
  endif
endif

template_url = https://${S3_INSTALL_BUCKET}.s3.amazonaws.com/${S3_INSTALL_PREFIX}/MirrorRepos/MirrorRepos.template.yml

upload:
	aws s3 cp --recursive . s3://${S3_INSTALL_BUCKET}/${S3_INSTALL_PREFIX}/MirrorRepos/
	@echo "CloudFormation template: ${template_url}"

create:
	aws cloudformation create-stack --stack-name ${STACK_NAME} \
	--template-url ${template_url} \
	--parameters \
		ParameterKey=S3InstallBucket,ParameterValue=${S3_INSTALL_BUCKET} \
		ParameterKey=S3InstallFolder,ParameterValue=${S3_INSTALL_PREFIX} \
		ParameterKey=S3MirrorRepoBucket,ParameterValue=${S3_MIRROR_REPO_BUCKET} \
		ParameterKey=S3MirrorRepoFolder,ParameterValue=${S3_MIRROR_REPO_FOLDER} \
	--disable-rollback \
	--capabilities CAPABILITY_IAM

update:
	aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-url ${template_url} \
	--parameters \
		ParameterKey=S3InstallBucket,ParameterValue=${S3_INSTALL_BUCKET} \
		ParameterKey=S3InstallFolder,ParameterValue=${S3_INSTALL_PREFIX} \
		ParameterKey=S3MirrorRepoBucket,ParameterValue=${S3_MIRROR_REPO_BUCKET} \
		ParameterKey=S3MirrorRepoFolder,ParameterValue=${S3_MIRROR_REPO_FOLDER} \
	--capabilities CAPABILITY_IAM
