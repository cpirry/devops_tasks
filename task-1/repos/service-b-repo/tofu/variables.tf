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

variable "consumer_account_id" {
  description = "Account ID of PrivateLink consumer (Service A)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
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
  description = "Target value for the auto-scaling metric (CPU %)"
  type        = number
}

variable "enable_xray" {
  description = "Whether to enable X-Ray monitoring on the service"
  type        = bool
}

variable "app_log_retention_days" {
  description = "The number of days to retain app logs"
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
  description = "Port for the NLB test (green) listener during blue/green deployments. Must differ from service_port"
  type        = number
  default     = null
}

variable "image_name" {
  description = "The name of the image in the ECR repository"
  type        = string
}

variable "image_tag" {
  description = "The tag of the image in the ECR repository"
  type        = string
}

variable "db_engine_version" {
  description = "MySQL engine version (e.g. '8.0.36')"
  type        = string
}

variable "db_mysql_major_version" {
  description = "MySQL major version string used for parameter group family (e.g. '8.0')"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance type (e.g. 'db.t3.medium')"
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
}

variable "db_database_name" {
  description = "Name of the initial database to create"
  type        = string
}

variable "db_master_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
}

# more database variables

variable "jwt_public_key" {
  description = "PEM-encoded RSA public key used to verify inbound JWTs from Service A"
  type        = string
  sensitive   = true
}

variable "db_alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to send RDS CloudWatch alarm notifications to"
  type        = list(string)
  default     = []
}

variable "sqs_alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to send SQS and Lambda CloudWatch alarm notifications to"
  type        = list(string)
  default     = []
}