output "dns_name" {
  description = "DNS name of the interface endpoint"
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "endpoint_id" {
  description = "ID of the VPC interface endpoint"
  value       = aws_vpc_endpoint.this.id
}

output "security_group_id" {
  description = "ID of the security group attached to the interface endpoint"
  value       = aws_security_group.this.id
}
