variable "project_name" {
  description = "The name of the project, used as a prefix in resource names"
  type        = string
}

variable "environment" {
  description = "The deployment environment"
  type        = string
}

variable "target_account_id" {
  description = "The ID of the AWS account to deploy resources to"
  type        = string
}

variable "target_account_region" {
  description = "The AWS region being used"
  type        = string
}

variable "state_account_id" {
  description = "The ID of the AWS account that stores remote states"
  type        = string
}

variable "state_account_region" {
  description = "The region that remote states are stored in"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ). Must fall within vpc_cidr"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ). Must fall within vpc_cidr"
  type        = list(string)
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateways in the public subnets"
  type        = bool
  default     = false
}

variable "create_s3_gateway_endpoint" {
  description = "Whether to create a Gateway endpoint for S3"
  type        = bool
  default     = true
}

variable "create_waf" {
  description = "When true, a WAF Web ACL with AWS Managed Rules is created and associated with the ALB"
  type        = bool
  default     = false
}

variable "app_url" {
  description = "The URL of the application API (e.g. api.my-app.com)"
  type        = string
}

variable "spa_url" {
  description = "The URL of the SPA frontend (e.g. my-app.com)"
  type        = string
}

variable "zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "desired_count" {
  description = "The number of desired ECS tasks to deploy"
  type        = number
}

variable "min_tasks" {
  description = "The minimum number of desired ECS tasks"
  type        = number
}

variable "max_tasks" {
  description = "The maximum number of desired ECS tasks to scale to"
  type        = number
}

variable "scaling_target_value" {
  description = "Target value for the auto-scaling metric (ALB requests per target)"
  type        = number
}

variable "task_cpu" {
  description = "The number of CPU units assigned to the task"
  type        = number
}

variable "task_memory" {
  description = "The amount of memory assigned to the task"
  type        = number
}

variable "service_port" {
  description = "The port number that the service listens for traffic on"
  type        = string
}

variable "test_port" {
  description = "Port for the ALB test (green) HTTPS listener during blue/green deployments. Must differ from service_port (e.g. 8443)."
  type        = number
  default     = null
}

variable "enable_xray" {
  description = "Whether to Xray monitoring on the service"
  type        = bool
}

variable "app_log_retention_days" {
  description = "The number of days to retain app logs"
  type        = number
}

variable "image_name" {
  description = "The name of the image in the ECR repository"
  type        = string
}

variable "image_tag" {
  description = "The tag of the image in the ECR repository"
  type        = string
}

variable "provider_service_port" {
  description = "The port that the provider service(s) listen on"
  type        = number
}

variable "jwt_private_key" {
  description = "PEM-encoded RSA private key used to sign JWTs issued to Service B"
  type        = string
  sensitive   = true
}