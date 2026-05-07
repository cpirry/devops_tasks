output "db_instance_id" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_address" {
  description = "Hostname of the RDS instance endpoint"
  value       = aws_db_instance.this.address
}

output "db_instance_endpoint" {
  description = "Full connection endpoint including port (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "rds_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.this.name
}

output "rds_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the RDS instance"
  value       = aws_kms_key.rds.arn
}

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the Secrets Manager secret"
  value       = aws_kms_key.secrets.arn
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = aws_backup_vault.this.arn
}

output "backup_plan_id" {
  description = "ID of the AWS Backup plan"
  value       = aws_backup_plan.this.id
}

output "monitoring_role_arn" {
  description = "ARN of the enhanced monitoring IAM role"
  value       = aws_iam_role.enhanced_monitoring.arn
}
