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
  vcp_cidr = "10.0.0.0/16"
  subnet_cidrs = {
    "public" : cidrsubnet(local.vcp_cidr, 8, 0),
    "private" : cidrsubnet(local.vcp_cidr, 8, 1),
  }
  private_ipv6_64 = cidrsubnet(aws_vpc.my_vpc.ipv6_cidr_block, 8, 1)
}

############### VPC
resource "aws_vpc" "my_vpc" {
  cidr_block                       = local.vcp_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true # IMPORTANT FOR DNS RESOLVE
  enable_dns_hostnames             = true # IMPORTANT FOR DNS RESOLVE
}

############### GATEWAYS
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

############### SUBNETS
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = local.subnet_cidrs["public"]
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true
}
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = local.subnet_cidrs["private"]
  availability_zone = "us-west-1a"
}

############### ROUTING TABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

############### ROUTING TABLES ASSOCIATIONS
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

############### NACL
# using the default NACL

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

############# DHCP OPTIONS
/*
We are creating a DHCP option set because we want a custom
search suffix (corp.internal), this is optional
*/
resource "aws_vpc_dhcp_options" "corp_internal" {
  domain_name                       = "corp.internal"
  domain_name_servers               = ["AmazonProvidedDNS"]
  tags = {
    Name = "corp.internal"
  }
}
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.my_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.corp_internal.id
}

############# PRIVATE HOSTED ZONE (PHZ)
resource "aws_route53_zone" "private" {
  name          = "corp.internal"
  comment       = "Private hosted zone for corp"
  force_destroy = true

  vpc {
    vpc_id     = aws_vpc.my_vpc.id
    vpc_region = "us-west-1"
  }
}

resource "aws_route53_record" "private_instance" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "privateinstance"
  type    = "A"
  ttl     = 300
  records = [aws_instance.private_instance.private_ip]
}
resource "aws_route53_record" "public_instance" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "publicinstance"
  type    = "A"
  ttl     = 300
  records = [aws_instance.public_instance.private_ip]
}



############### INSTANCES
resource "aws_instance" "public_instance" {
  ami                    = "ami-0945610b37068d87a"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = "kali-key"
}

resource "aws_instance" "private_instance" {
  ami                    = "ami-0945610b37068d87a"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = "kali-key"
}


output "public_instance" {
  value = aws_instance.public_instance.public_ip
}
output "private_instance" {
  value = {
    private_ip  = aws_instance.private_instance.private_ip
    private_dns = aws_instance.private_instance.private_dns
  }
}
