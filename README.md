# Terraform-ec2-rds-django-api

## Requirements
- Terraform: [Instalation guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- AWS-CLI: [Instalation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Configure
Modify the contents of `example/main.tf` with the desired values

## Deploy
```bash
cd example
terraform init
terraform deploy
```