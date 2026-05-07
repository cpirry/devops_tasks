variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "kms_key_id" {
  description = "ARN of the KMS key used to encrypt bucket contents"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
