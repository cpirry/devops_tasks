variable "project_name" {
  description = "The name of the project, used as a prefix in resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to deploy into. Must have the same length as the subnet CIDR lists"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)"
  type        = list(string)
}

variable "create_public_subnets" {
  description = "Whether to create public subnets and an Internet Gateway"
  type        = bool
  default     = false
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateways in the public subnets"
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention period in days for VPC Flow Log CloudWatch log group"
  type        = number
  default     = 30
}

variable "interface_endpoint_services" {
  description = <<-EOT
    List of AWS service names to create Interface VPC Endpoints for.
    Examples: ["ecr.api", "ecr.dkr", "secretsmanager", "logs", "monitoring", "sqs"]
  EOT
  type        = list(string)
  default     = []
}

variable "create_s3_gateway_endpoint" {
  description = "Whether to create a Gateway endpoint for S3"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}