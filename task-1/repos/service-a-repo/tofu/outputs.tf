output "privatelink_endpoint_sg_id" {
  description = "Security group ID of the PrivateLink interface endpoint. Pass this to service-b as var.consumer_endpoint_sg_id to restrict NLB inbound to this SG only."
  value       = module.service_b_endpoint.security_group_id
}
