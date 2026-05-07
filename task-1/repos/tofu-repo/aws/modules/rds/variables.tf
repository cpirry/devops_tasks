variable "project_name" {
  description = "The name of the project, used as a prefix in resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC (Account B)"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "source_security_group_id" {
  description = "Security group ID of the source resource that will access RDS"
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version (e.g. '8.0.36')"
  type        = string
  default     = "8.0.36"
}

variable "mysql_major_version" {
  description = "MySQL major version string used for parameter group family (e.g. '8.0')"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance type (e.g. 'db.t3.medium')"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for autoscaling storage in GiB"
  type        = number
  default     = 100
}

variable "master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "database_name" {
  description = "Name of the initial database to create"
  type        = string
}


variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window in UTC (e.g. '02:00-03:00')"
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (e.g. 'Mon:04:00-Mon:05:00')"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on deletion"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of the Secrets Manager rotation Lambda. Required to enable automatic rotation"
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Number of days between automatic secret rotations"
  type        = number
  default     = 30
}

variable "backup_schedule" {
  description = "Cron expression for the AWS Backup schedule (default: daily at 01:00 UTC)"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "backup_copy_region" {
  description = "AWS region to copy backups to for cross-region redundancy. Leave null to disable"
  type        = string
  default     = null
}

variable "backup_copy_kms_key_arn" {
  description = "KMS key ARN in the copy region used to encrypt the replicated backup vault"
  type        = string
  default     = null
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to send CloudWatch alarm notifications to"
  type        = list(string)
  default     = []
}

variable "free_storage_alarm_threshold_bytes" {
  description = "Free storage space threshold in bytes"
  type        = number
  default     = 5368709120 # 5 GiB
}

variable "latency_alarm_threshold_seconds" {
  description = "Read/write latency threshold in seconds"
  type        = number
  default     = 0.02
}

variable "tags" {
  description = "Map of tags applied to all resources"
  type        = map(string)
  default     = {}
}
