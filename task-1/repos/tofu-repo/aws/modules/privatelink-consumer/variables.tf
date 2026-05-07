variable "project_name" {
  description = "Project name used as a prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the endpoint and security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs to associate with the interface endpoint"
  type        = list(string)
}

variable "provider_endpoint_service_name" {
  description = "The PrivateLink endpoint service name from the provider account"
  type        = string
}

variable "ecs_task_security_group_id" {
  description = "Security group ID of the ECS tasks that will call the provider"
  type        = string
}

variable "service_port" {
  description = "The service port"
  type        = number
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
