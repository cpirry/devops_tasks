variable "project_name" {
  description = "The name of the project, used as a prefix in resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used for CloudWatch log configuration)"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "ID of the VPC in which to deploy the ECS service"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs the ECS tasks will be placed in"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "container_name" {
  description = "Name of the application container within the task definition"
  type        = string
}

variable "container_image" {
  description = "Full ECR image URL including tag"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
}

variable "environment_variables" {
  description = "Non-sensitive environment variables injected into the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs the execution role must be able to read"
  type        = list(string)
  default     = []
}

variable "secret_mappings" {
  description = "List of Secrets Manager values to inject as environment variables into the container"
  type = list(object({
    env_var    = string
    secret_arn = string
  }))
  default = []
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory for the task in MiB"
  type        = number
  default     = 1024
}

variable "health_check" {
  description = "Container-level health check configuration"
  type = object({
    command      = string 
    interval     = number
    timeout      = number
    retries      = number
    start_period = number
  })
  default = null
}

variable "health_check_grace_period" {
  description = "Number of seconds ECS waits before starting health checks after a task starts"
  type        = number
  default     = 60
}

variable "target_group_arn" {
  description = "ARN of the ALB/NLB target group to register tasks with"
  type        = string
  default     = null
}

variable "min_tasks" {
  description = "Minimum number of running ECS tasks"
  type        = number
  default     = 2
}

variable "desired_count" {
  description = "Initial desired count of ECS tasks"
  type        = number
  default     = 2
}

variable "max_tasks" {
  description = "Maximum number of ECS tasks when scaled out"
  type        = number
  default     = 8
}

variable "scaling_policy_type" {
  description = <<-EOT
    Selects the auto-scaling metric:
      "alb_request_count": ALB request count per target
      "cpu": average CPU utilisation.
  EOT
  type        = string
  default     = "cpu"

  validation {
    condition     = contains(["alb_request_count", "cpu"], var.scaling_policy_type)
    error_message = "scaling_policy_type must be one of: alb_request_count, cpu"
  }
}

variable "scaling_target_value" {
  description = "Target value for the auto-scaling metric (requests/target or CPU %)"
  type        = number
  default     = 70
}

variable "scale_in_cooldown" {
  description = "Cooldown in seconds after a scale-in event"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown in seconds after a scale-out event"
  type        = number
  default     = 60
}

variable "alb_resource_label" {
  description = <<-EOT
    Required when scaling_policy_type = "alb_request_count".
    Format: <alb-arn-suffix>/<target-group-arn-suffix>
    Example: app/my-alb/abc123/targetgroup/my-tg/def456
  EOT
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_xray_sidecar" {
  description = "Whether to attach an AWS X-Ray daemon sidecar container"
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = <<-EOT
    List of ingress rules for the ECS tasks security group.
    Each rule must specify: description, from_port, to_port, protocol.
    Provide either source_security_group_id or cidr_ipv4.
  EOT
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    source_security_group_id = optional(string)
    cidr_ipv4                = optional(string)
  }))
  default = []
}

variable "task_policy_json" {
  description = "JSON-encoded IAM policy document attached to the task role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
