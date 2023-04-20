# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Create a custom VPC
resource "aws_vpc" "custom" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Custom_VPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom.id
}

# Create a public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.custom.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

# Create a NAT Gateway
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  subnet_id      = aws_subnet.public1.id
  allocation_id  = aws_eip.nat.id
}

# Create a private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.custom.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private_Route_Table"
  }
}

# Create 2 public subnets
resource "aws_subnet" "public1" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.custom.id
  tags = {
    Name = "Public_Subnet_1"
  }
}

resource "aws_subnet" "public2" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.custom.id
  tags = {
    Name = "Public_Subnet_2"
  }
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# Create 2 private subnets
resource "aws_subnet" "private1" {
  cidr_block = "10.0.3.0/24"
  vpc_id     = aws_vpc.custom.id
  tags = {
    Name = "Private_Subnet_1"
  }
}

resource "aws_subnet" "private2" {
  cidr_block = "10.0.4.0/24"
  vpc_id     = aws_vpc.custom.id
  tags = {
    Name = "Private_Subnet_2"
  }
}

# Associate the private route table with the private subnets
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# Create a security group allowing all incoming and outgoing traffic
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.custom.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fetch the Amazon Linux 2 AMI information
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-gp2"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  owners = ["amazon"]
}

# Create a launch configuration for the webserver
resource "aws_launch_configuration" "webserver" {
  name_prefix     = "webserver"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.allow_all.id]

  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "Hello from Terraform!" > /var/www/html/index.html
                EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create an Auto Scaling group for the webserver
resource "aws_autoscaling_group" "webserver" {
  name                 = "webserver"
  desired_capacity     = var.min_size
  min_size             = var.min_size
  max_size             = var.max_size
  vpc_zone_identifier  = [aws_subnet.private1.id, aws_subnet.private2.id]
  launch_configuration = aws_launch_configuration.webserver.name
}

# Create the Application Load Balancer
resource "aws_lb" "alb" {
  name               = "webserver-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_all.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
}

# Create a target group for the ALB
resource "aws_lb_target_group" "alb" {
  name     = "webserver-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom.id
}

# Associate the target group with the ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}

# Attach the Auto Scaling group to the ALB target group
resource "aws_autoscaling_attachment" "alb" {
  autoscaling_group_name = aws_autoscaling_group.webserver.id
  lb_target_group_arn    = aws_lb_target_group.alb.arn
}

# Output the public DNS of the ALB
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
  description = "The public DNS of the Application Load Balancer"
}
