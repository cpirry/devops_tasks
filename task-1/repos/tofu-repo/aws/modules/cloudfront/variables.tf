variable "description" {
  description = "A description of the CloudFront distribution"
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used as the origin"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "domain_aliases" {
  description = "Custom domain names for the distribution (e.g. [\"my-app.com\"])"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
}

variable "cache_policy_name" {
  description = "Name of a CloudFront managed or custom cache policy (e.g. \"Managed-CachingOptimized\")"
  type        = string
  default     = "Managed-CachingOptimized"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "waf_web_acl_arn" {
  description = "ARN of a WAFv2 Web ACL to associate with the distribution"
  type        = string
  default     = null
}

variable "access_logs_bucket" {
  description = "S3 bucket domain name for CloudFront access logs (e.g. \"mylogs.s3.amazonaws.com\")"
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
