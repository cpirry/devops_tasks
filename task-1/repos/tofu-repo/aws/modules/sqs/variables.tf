variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt both SQS queues"
  type        = string
}

variable "producer_role_arn" {
  description = "ARN of the IAM role permitted to send messages to the main queue (Service B ECS task role)"
  type        = string
}

variable "ses_sender_address" {
  description = "Verified SES email address used as the From address — Lambda SES permissions are scoped to this address"
  type        = string
}

variable "lambda_s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package, uploaded by the CI/CD pipeline"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key of the Lambda deployment package (e.g. email-worker/v1.0.0/handler.zip)"
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_batch_size" {
  description = "Maximum number of SQS messages passed to Lambda per invocation"
  type        = number
  default     = 10
}

variable "lambda_batching_window_seconds" {
  description = "Seconds Lambda waits to fill a batch before invoking (0 = invoke immediately)"
  type        = number
  default     = 0
}

variable "lambda_max_concurrency" {
  description = "Maximum concurrent Lambda invocations from this SQS trigger — limits SES send rate"
  type        = number
  default     = 10
}

variable "visibility_timeout_seconds" {
  description = "SQS visibility timeout in seconds — must be at least 6x lambda_timeout_seconds to avoid duplicate processing"
  type        = number
  default     = 180
}

variable "retention_seconds" {
  description = "Main queue message retention period in seconds (default: 4 days)"
  type        = number
  default     = 345600
}

variable "dlq_retention_seconds" {
  description = "DLQ message retention period in seconds (default: 14 days)"
  type        = number
  default     = 1209600
}

variable "max_receive_count" {
  description = "Number of times a message can be received before being moved to the DLQ"
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs in CloudWatch"
  type        = number
}

variable "log_level" {
  description = "Application log level passed to the Lambda function (INFO, WARN, ERROR)"
  type        = string
  default     = "INFO"
}

variable "queue_depth_alarm_threshold" {
  description = "Number of visible messages in the main queue that triggers the depth alarm"
  type        = number
  default     = 100
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to notify when alarms fire or recover"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
