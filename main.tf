// Default network
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
     name   = "vpc-id"
     values = [local.vpc_id]
  }
}

data "aws_caller_identity" "aws" {}

locals {
  vpc_id    = length(var.vpc_id) > 0 ? var.vpc_id : data.aws_vpc.default.id
  subnet_id = length(var.subnet_id) > 0 ? var.subnet_id : sort(data.aws_subnets.default.ids)[0]
  tf_tags = {
    Terraform = true,
    By        = data.aws_caller_identity.aws.arn
  }
}

// Keep labels, tags consistent
module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=main"

  namespace   = var.namespace
  stage       = var.environment
  name        = var.name
  delimiter   = "-"
  label_order = ["environment", "stage", "name", "attributes"]
  tags        = merge(var.tags, local.tf_tags)
}

// Amazon Linux2 AMI - can switch this to default by editing the EC2 resource below
data "aws_ami" "amazon-linux-2" {
  most_recent = true

  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

// Find latest Ubuntu AMI, use as default if no AMI specified
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical Id
}


resource "aws_iam_role" "allow_s3" {
  name   = "${module.label.id}-allow-ec2-to-s3"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${module.label.id}-instance-profile"
  role = aws_iam_role.allow_s3.name
}

// Script to configure the server - this is where most of the magic occurs!
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    application_root    = var.application_root
    application_port    = var.application_port
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "postgres"
  # engine_version       = "16.3-R2"
  instance_class       = "db.t3.micro"
  # name                 = "${var.name}-db"
  username             = var.db_username
  password             = var.db_password
  # parameter_group_name = "default.postgres13"
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  tags = module.label.tags
}

module "rds_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "${var.name}-rds"
  vpc_id = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Allow PostgreSQL access from EC2"
      cidr_blocks = var.allowed_cidrs
    },
  ]

  tags = module.label.tags
}

module "ec2_security_group" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=master"

  name        = "${var.name}-ec2"
  description = "Allow SSH and TCP ${var.application_port}"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks      = [ var.allowed_cidrs ]
  ingress_rules            = [ "ssh-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = var.application_port
      to_port     = var.application_port
      protocol    = "tcp"
      description = "my_application server"
      cidr_blocks = var.allowed_cidrs
    },
  ]
  egress_rules = ["all-all"]

  tags = module.label.tags
}

// Create EC2 ssh key pair
resource "tls_private_key" "ec2_ssh" {
  count = length(var.key_name) > 0 ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_ssh" {
  count = length(var.key_name) > 0 ? 0 : 1

  key_name   = "${var.name}-ec2-ssh-key"
  public_key = tls_private_key.ec2_ssh[0].public_key_openssh
}

locals {
  _ssh_key_name = length(var.key_name) > 0 ? var.key_name : aws_key_pair.ec2_ssh[0].key_name
}

// EC2 instance for the server - tune instance_type to fit your performance and budget requirements
module "ec2_instance" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=master"
  name   = "${var.name}-public"

  # instance
  key_name             = local._ssh_key_name
  ami                  = var.ami != "" ? var.ami : data.aws_ami.ubuntu.image_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.id
  user_data            = data.template_file.user_data.rendered

  # network
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [ module.ec2_security_group.security_group_id ]
  associate_public_ip_address = var.associate_public_ip_address

  tags = module.label.tags
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
