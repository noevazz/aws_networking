terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.2"
}


provider "aws" {
  region = "us-west-1"
}

locals {
  subnet_cidrs = {
    "public" : cidrsubnet(var.vcp_cidr, 8, 0),
    "private" : cidrsubnet(var.vcp_cidr, 8, 1),
  }
}

############### VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vcp_cidr
}

############### INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

############### NAT GATEWAY
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "eip-nat" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = module.public_subnet.subnet_id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

############### ROUTING TABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "through_nat_gw" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "public-rt" }
}

############### SUBNETS
module "public_subnet" {
  source                  = "./modules/subnet"
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = local.subnet_cidrs["public"]
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true
}

module "private_subnet" {
  source                  = "./modules/subnet"
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = local.subnet_cidrs["private"]
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = false
}

############### ROUTING TABLES ASSOCIATIONS
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = module.public_subnet.subnet_id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = module.private_subnet.subnet_id
  route_table_id = aws_route_table.through_nat_gw.id
}

############### SECURITY GROUP
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.subnet_cidrs["public"]]
  }

  ingress {
    from_port   = 8 # echo-request
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.subnet_cidrs["public"]]
  }
  egress {
    from_port   = 8 # echo-request
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############### NACL
# using the default NACL

############### INSTANCES
resource "aws_instance" "public_instance" {
  ami                    = "ami-0945610b37068d87a"
  instance_type          = "t3.micro"
  subnet_id              = module.public_subnet.subnet_id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = "kali-key"
}

resource "aws_instance" "private_instance" {
  ami                    = "ami-0945610b37068d87a"
  instance_type          = "t3.micro"
  subnet_id              = module.private_subnet.subnet_id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = "kali-key"
}

