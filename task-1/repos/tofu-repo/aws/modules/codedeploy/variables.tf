variable "project_name" {
  type        = string
  description = "Project/service name"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name"
}

variable "prod_listener_arn" {
  type        = string
  description = "ALB production listener ARN"
}

variable "test_listener_arn" {
  type        = string
  description = "ALB test listener ARN"
}

variable "blue_target_group_name" {
  type        = string
  description = "Primary/blue target group name"
}

variable "green_target_group_name" {
  type        = string
  description = "Green target group name"
}

variable "deployment_config_name" {
  type        = string
  description = "CodeDeploy ECS deployment strategy"
}

variable "blue_termination_wait_minutes" {
  type        = number
  default     = 5
  description = "How long to keep blue tasks alive after successful deployment"
}

variable "alarm_names" {
  type        = list(string)
  default     = []
  description = "CloudWatch alarms that trigger automatic rollback"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to resources"
}
