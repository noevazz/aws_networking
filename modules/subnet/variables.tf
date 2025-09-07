variable "vpc_id" {}
variable "cidr_block" {}
variable "availability_zone" {}
variable "map_public_ip_on_launch" {}
variable "assign_ipv6_address_on_creation" {}
variable "ipv6_cidr_block" {
  type    = string
  default = null    # <- omit for non-IPv6 subnets
}