output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of AZ -> subnet ID for public subnets"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "public_subnet_ids_list" {
  description = "List of public subnet IDs"
  value       = [for az in var.availability_zones : aws_subnet.public[az].id if var.create_public_subnets]
}

output "private_subnet_ids" {
  description = "Map of AZ -> subnet ID for private subnets"
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "private_subnet_ids_list" {
  description = "List of private subnet IDs"
  value       = [for az in var.availability_zones : aws_subnet.private[az].id]
}

output "nat_gateway_ids" {
  description = "Map of AZ -> NAT Gateway ID"
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}

output "nat_gateway_public_ips" {
  description = "Map of AZ -> Elastic IP address used by the NAT Gateway"
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway (empty string if not created)"
  value       = var.create_public_subnets ? aws_internet_gateway.this[0].id : ""
}

output "endpoint_security_group_id" {
  description = "Security group ID attached to Interface VPC Endpoints"
  value       = length(var.interface_endpoint_services) > 0 ? aws_security_group.endpoints[0].id : ""
}

output "interface_endpoint_ids" {
  description = "Map of service name -> VPC Endpoint ID for Interface Endpoints"
  value       = { for svc, ep in aws_vpc_endpoint.interface : svc => ep.id }
}

output "s3_gateway_endpoint_id" {
  description = "The ID of the S3 Gateway Endpoint (empty string if not created)"
  value       = var.create_s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].id : ""
}

output "private_route_table_ids" {
  description = "Map of AZ -> private route table ID"
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}
