terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region for Hitachi SDS deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type for Hitachi SDS nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "hitachi_node_count" {
  description = "Number of Hitachi SDS nodes"
  type        = number
  default     = 3
}

variable "hitachi_root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "hitachi_data_volume_size" {
  description = "Data volume size in GB per node"
  type        = number
  default     = 500
}

variable "hitachi_journal_volume_size" {
  description = "Journal volume size in GB per node"
  type        = number
  default     = 50
}

variable "hitachi_vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "hitachi_subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.1.0.0/24"
}

variable "hitachi_enable_public_ip" {
  description = "Enable public IP for instances"
  type        = bool
  default     = true
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# VPC
resource "aws_vpc" "hitachi" {
  cidr_block           = var.hitachi_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hitachi-sds-vpc"
  }
}

# Subnet
resource "aws_subnet" "hitachi" {
  vpc_id                  = aws_vpc.hitachi.id
  cidr_block              = var.hitachi_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = var.hitachi_enable_public_ip

  tags = {
    Name = "hitachi-sds-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "hitachi" {
  vpc_id = aws_vpc.hitachi.id

  tags = {
    Name = "hitachi-sds-igw"
  }
}

# Route Table
resource "aws_route_table" "hitachi" {
  vpc_id = aws_vpc.hitachi.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.hitachi.id
  }

  tags = {
    Name = "hitachi-sds-rt"
  }
}

resource "aws_route_table_association" "hitachi" {
  subnet_id      = aws_subnet.hitachi.id
  route_table_id = aws_route_table.hitachi.id
}

# Security Group
resource "aws_security_group" "hitachi" {
  name        = "hitachi-sds-sg"
  description = "Security group for Hitachi SDS nodes"
  vpc_id      = aws_vpc.hitachi.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # iSCSI
  ingress {
    from_port   = 3260
    to_port     = 3260
    protocol    = "tcp"
    cidr_blocks = [var.hitachi_vpc_cidr]
  }

  # Management interface
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.hitachi_vpc_cidr]
  }

  # Replication
  ingress {
    from_port   = 19000
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = [var.hitachi_vpc_cidr]
  }

  # Internal cluster communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  # Egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hitachi-sds-sg"
  }
}

# EC2 Instances
resource "aws_instance" "hitachi_nodes" {
  count                = var.hitachi_node_count
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.aws_instance_type
  subnet_id            = aws_subnet.hitachi.id
  vpc_security_group_ids = [aws_security_group.hitachi.id]
  iam_instance_profile = aws_iam_instance_profile.hitachi.name

  root_block_device {
    volume_size           = var.hitachi_root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "hitachi-node-${count.index}-root"
    }
  }

  tags = {
    Name = "hitachi-sds-node-${count.index}"
    Type = "hitachi-sds"
  }

  depends_on = [aws_internet_gateway.hitachi]
}

# Data volumes for each node
resource "aws_ebs_volume" "hitachi_data" {
  count             = var.hitachi_node_count
  availability_zone = aws_subnet.hitachi.availability_zone
  size              = var.hitachi_data_volume_size
  type              = "gp3"

  tags = {
    Name = "hitachi-node-${count.index}-data"
  }
}

resource "aws_volume_attachment" "hitachi_data" {
  count           = var.hitachi_node_count
  device_name     = "/dev/sdf"
  volume_id       = aws_ebs_volume.hitachi_data[count.index].id
  instance_id     = aws_instance.hitachi_nodes[count.index].id
  force_detach    = true
}

# Journal volumes for each node
resource "aws_ebs_volume" "hitachi_journal" {
  count             = var.hitachi_node_count
  availability_zone = aws_subnet.hitachi.availability_zone
  size              = var.hitachi_journal_volume_size
  type              = "gp3"

  tags = {
    Name = "hitachi-node-${count.index}-journal"
  }
}

resource "aws_volume_attachment" "hitachi_journal" {
  count           = var.hitachi_node_count
  device_name     = "/dev/sdg"
  volume_id       = aws_ebs_volume.hitachi_journal[count.index].id
  instance_id     = aws_instance.hitachi_nodes[count.index].id
  force_detach    = true
}

# IAM Role for EC2 instances
resource "aws_iam_role" "hitachi" {
  name = "hitachi-sds-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "hitachi" {
  name = "hitachi-sds-profile"
  role = aws_iam_role.hitachi.name
}

# Outputs
output "hitachi_node_ips" {
  description = "Private IP addresses of Hitachi SDS nodes"
  value       = aws_instance.hitachi_nodes[*].private_ip
}

output "hitachi_node_public_ips" {
  description = "Public IP addresses of Hitachi SDS nodes"
  value       = aws_instance.hitachi_nodes[*].public_ip
}

output "hitachi_node_ids" {
  description = "Instance IDs of Hitachi SDS nodes"
  value       = aws_instance.hitachi_nodes[*].id
}

output "hitachi_vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.hitachi.id
}

output "hitachi_subnet_id" {
  description = "Subnet ID"
  value       = aws_subnet.hitachi.id
}

output "hitachi_security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.hitachi.id
}
