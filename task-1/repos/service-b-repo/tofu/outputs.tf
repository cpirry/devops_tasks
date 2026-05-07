output "endpoint_service_name" {
  description = "Name of the PrivateLink endpoint service. Pass this to service-a (via remote state) to create the interface endpoint."
  value       = module.nlb.endpoint_service_name
}
