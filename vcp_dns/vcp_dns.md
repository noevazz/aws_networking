# AWS Lab: Private Hosted Zones and DHCP Option Sets with Terraform

This lab demonstrates how to build a custom AWS networking environment using Terraform to study two key features:

- Private Hosted Zones (PHZ) – internal DNS zones that allow name resolution only inside a VPC.
- DHCP Option Sets – custom DNS search suffixes and resolvers that control how instances resolve hostnames.

By combining these with a simple VPC, subnets, routing, and EC2 instances, you can simulate a small internal corporate network (corp.internal) and practice how AWS handles private DNS resolution.

## Key Notes

1. DNS Resolution in VPC
    - `enable_dns_support = true` and `enable_dns_hostnames = true` are essential for PHZ resolution.
2. Route 53 PHZ Scope
    - Private zones only resolve inside the VPC(s) they’re associated with.
    - Attempting to query corp.internal from outside the VPC will fail.

