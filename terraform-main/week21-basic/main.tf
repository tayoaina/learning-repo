# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Fetch the default VPC information
data "aws_vpc" "default" {
  default = true
}

# Fetch the default VPC subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a security group allowing traffic on port 8080 and all inbound/outbound traffic
resource "aws_security_group" "allow_8080_and_all" {
  name        = "allow_8080_and_all"
  description = "Allow traffic on port 8080 and all inbound/outbound traffic"

  # Allow inbound traffic on port 8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group allowing HTTP traffic
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a launch configuration for the webserver
resource "aws_launch_configuration" "webserver" {
  name          = "webserver"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  security_groups = [
    aws_security_group.allow_http.id,
    aws_security_group.allow_8080_and_all.id,
  ]

  # User data script to install and start Apache webserver
  user_data = <<-EOF
  #!/bin/bash
  sleep 60
  yum update -y
  yum install -y httpd aws-cli
  systemctl start httpd
  systemctl enable httpd
  echo "Hello, World!" > /var/www/html/index.html
  aws s3 cp /var/log/user-data.log s3://week21/user-data-logs/instance-\$(date -u +"%Y-%m-%dT%H-%M-%SZ").log
  EOF
}

# Create an Auto Scaling group for the webserver
resource "aws_autoscaling_group" "webserver" {
  name                 = "webserver"
  desired_capacity     = var.min_size
  min_size             = var.min_size
  max_size             = var.max_size
  vpc_zone_identifier  = data.aws_subnets.default.ids
  launch_configuration = aws_launch_configuration.webserver.name
}

# Fetch the Amazon Linux 2 AMI information
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

# Create an S3 bucket for the backend
resource "aws_s3_bucket" "backend" {
  bucket = "week21"
}
