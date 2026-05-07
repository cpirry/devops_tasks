resource "aws_kms_key" "rds" {
  description             = "${var.project_name} RDS encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for ${var.project_name} RDS instance"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Controls access to the ${var.project_name} RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL access from source resources"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

# unimplemented:
resource "aws_db_parameter_group" "this" {
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = var.engine_version
  parameter_group_name = aws_db_parameter_group.this.name

  # Instance sizing
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"

  # Credentials (initial password managed via Secrets Manager rotation)
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High availability
  multi_az = var.multi_az

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Backups
  backup_retention_period   = var.backup_retention_days
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false

  # Monitoring
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports = ["general", "slowquery", "error"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  # Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-final-snapshot"

  apply_immediately = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-mysql"
  })

  lifecycle {
    # Prevent Terraform from resetting the password after initial Secrets Manager rotation
    ignore_changes = [password]
  }
}

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_iam_role" "enhanced_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-secrets-kms"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/rds/credentials"
  description = "RDS master credentials for ${var.project_name} — managed by multi-user rotation"
  kms_key_id  = aws_kms_key.secrets.arn

  # Prevent accidental deletion
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    # database information
  })

  # Rotation will take over after initial creation
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  count = var.rotation_lambda_arn != null ? 1 : 0

  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-backup-kms"
  })
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_backup_vault" "this" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = var.tags
}

# Cross-region copy vault (in the copy destination region)
resource "aws_backup_vault" "copy" {
  count    = var.backup_copy_region != null ? 1 : 0
  provider = aws.backup_copy

  name        = "${var.project_name}-backup-vault-copy"
  kms_key_arn = var.backup_copy_kms_key_arn

  tags = var.tags
}

resource "aws_backup_plan" "this" {
  name = "${var.project_name}-backup-plan"

  rule {
    # rule configuration

    lifecycle {
      delete_after = var.backup_retention_days
    }

    dynamic "copy_action" {
      for_each = var.backup_copy_region != null ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.copy[0].arn

        lifecycle {
          delete_after = var.backup_retention_days
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "rds" {
  name         = "${var.project_name}-rds-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [aws_db_instance.this.arn]
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "free_storage" {
  alarm_name          = "${aws_db_instance.this.id}-rds-free-storage-low"
  alarm_description   = "RDS free storage space is critically low"
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "read_latency" {
  alarm_name          = "${aws_db_instance.this.id}-rds-read-latency-high"
  alarm_description   = "RDS read latency is high"
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "write_latency" {
  alarm_name          = "${aws_db_instance.this.id}-rds-write-latency-high"
  alarm_description   = "RDS write latency is high"
}
