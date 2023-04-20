variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "CIDR block for the subnet"
  default     = "10.0.1.0/24"
}

variable "auto_ipv4" {
  type        = bool
  description = "enable auto-assign ipv4"
  default     = true
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default     = "ami-0fa1de1d60de6a97e" # Amazon Linux 2 AMI 
}

variable "instance_type" {
  description = "Instance type for the EC2"
  default     = "t2.micro"
}

variable "bucket_name" {
  description = "S3 bucket name for Jenkins artifacts"
  default     = "billsjenkins-artifacts-bucketwk20"
}

variable "all_traffic" {
  description = "CIDR block for allowing all traffic"
  default     = "0.0.0.0/0"
}

variable "app_name" {
  description = "Name of the application"
  default     = "Jenkins"
}
