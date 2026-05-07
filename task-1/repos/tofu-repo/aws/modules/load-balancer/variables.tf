variable "project_name" {
  description = "The name of the project, used as a prefix in resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the load balancer"
  type        = list(string)
}

variable "lb_type" {
  description = "Type of load balancer"
  type        = string

  validation {
    condition     = contains(["alb", "nlb"], var.lb_type)
    error_message = "lb_type must be 'alb' or 'nlb'"
  }
}

variable "service_port" {
  description = "Port the attached service listens on"
  type        = number
}

variable "test_port" {
  description = "Port for the test (green) listener used during blue/green deployments"
  type        = number
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "TLS security policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "health_check_path" {
  description = "HTTP path for the ALB health check (e.g. /health)"
  type        = string
  default     = "/health"
}

# ...
# more healtcheck variables
# ...

variable "deregistration_delay" {
  description = "Time in seconds for the load balancer to wait before deregistering a target"
  type        = number
  default     = 30
}

variable "create_waf" {
  description = "When true, a WAF Web ACL with AWS Managed Rules is created and associated with the ALB"
  type        = bool
  default     = false
}

variable "waf_web_acl_arn" {
  description = "ARN of an existing WAF Web ACL to associate with the ALB. Ignored when create_waf = true"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = null
}

variable "create_endpoint_service" {
  description = "When true, a VPC Endpoint Service is created, backed by the NLB"
  type        = bool
  default     = false
}

variable "endpoint_service_allowed_principals" {
  description = "List of IAM principal ARNs allowed to create connections to the endpoint service"
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the load balancer"
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket name for LB access logs"
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
