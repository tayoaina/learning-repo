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

# Create a security group allowing traffic on port 80 and all inbound/outbound traffic
resource "aws_security_group" "allow_80_and_all" {
  name        = "allow_80_and_all"
  description = "Allow traffic on port 80 and all inbound/outbound traffic"

  # Allow inbound traffic on port 80
  ingress {
    from_port   = 80
    to_port     = 80
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

# Add the security group for ALB
resource "aws_security_group" "allow_http_alb" {
  name        = "allow_http_alb"
  description = "Allow HTTP traffic for ALB"

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
    aws_security_group.allow_80_and_all.id,
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

  target_group_arns = [aws_lb_target_group.alb_target_group.arn]
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

# Create the Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  name               = "week21-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_alb.id, aws_security_group.allow_80_and_all.id]
  subnets            = data.aws_subnets.default.ids
}

# Create a Target Group for the ALB
resource "aws_lb_target_group" "alb_target_group" {
  name     = "week21-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

# Configure the ALB to route traffic to the Target Group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

# Output the public DNS name of the Application Load Balancer
output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}
