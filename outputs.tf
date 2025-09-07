output "vpc_id" {
  description = "ID of the VPC"
  value = {
    id             = aws_vpc.my_vpc.id
    cidr_block      = aws_vpc.my_vpc.cidr_block
    ipv6_cidr_block = aws_vpc.my_vpc.ipv6_cidr_block
  }
}

output "public_instance" {
  value = {
    value     = module.public_subnet.subnet_id
    public_ip = aws_instance.public_instance.public_ip
  }
}

output "private_instance" {
  value = {
    id             = module.private_subnet.subnet_id
    private_ip     = aws_instance.private_instance.private_ip
    ipv6_addresses = aws_instance.private_instance.ipv6_addresses
  }
}

output "nat_gateway_ip" {
  value = aws_eip.nat.public_ip
}
