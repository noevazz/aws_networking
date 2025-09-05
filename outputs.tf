output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.my_vpc.id
}

output "public_subnet_id" {
  value = module.public_subnet.subnet_id  
}
output "private_subnet_id" {
  value = module.private_subnet.subnet_id  
}

output "public_instance_ip" {
  value = aws_instance.public_instance.public_ip
}

output "private_instance_ip" {
  value = aws_instance.private_instance.private_ip
}