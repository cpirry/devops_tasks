module "vpc" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/vpc?ref=v1.0.0"

  project_name         = var.project_name
  aws_region           = var.target_account_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = ["${var.target_account_region}a", "${var.target_account_region}b"]
  private_subnet_cidrs = var.private_subnet_cidrs

  create_public_subnets       = false
  create_nat_gateway          = var.create_nat_gateway
  interface_endpoint_services = ["ecr.api", "ecr.dkr", "logs", "monitoring", "secretsmanager", "sqs"]
  create_s3_gateway_endpoint  = var.create_s3_gateway_endpoint
}

module "nlb" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/load-balancer?ref=v1.0.0"

  project_name    = var.project_name
  lb_type         = "nlb"
  vpc_cidr        = var.vpc_cidr
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids_list
  service_port    = var.service_port
  test_port       = var.test_port
  
  create_endpoint_service             = true
  endpoint_service_allowed_principals = ["arn:aws:iam::${var.consumer_account_id}:root"]
}

module "ecs_service" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/ecs?ref=v1.0.0"

  project_name     = var.project_name

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids_list

  cluster_name     = "${var.project_name}-service-b-cluster"
  service_name     = "${var.project_name}-service-b"

  container_name   = "${var.project_name}-service-b-container"
  container_image  = "${var.target_account_id}.dkr.ecr.${var.target_account_region}.amazonaws.com/${var.image_name}:${var.image_tag}"
  container_port   = var.service_port
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory

  min_tasks     = var.min_tasks
  max_tasks     = var.max_tasks
  desired_count = var.desired_count

  scaling_policy_type  = "cpu"
  scaling_target_value = var.scaling_target_value

  environment_variables = [
    { name = "LOG_LEVEL", value = "info" }
  ]

  secret_arns = [
    module.database.db_credentials_secret_arn,
    module.jwt_public_key.secret_arn
  ]
  secret_mappings = [
    {
      env_var    = "DB_CREDENTIALS"
      secret_arn = module.database.db_credentials_secret_arn
    },
    {
      env_var    = "JWT_PUBLIC_KEY"
      secret_arn = module.jwt_public_key.secret_arn
    }
  ]

  health_check = {
    # healthchecks
  }

  ingress_rules = [
    {
      description              = "Allow TCP on service port from NLB"
      from_port                = var.service_port
      to_port                  = var.service_port
      protocol                 = "tcp"
      source_security_group_id = module.nlb.nlb_security_group_id
    }
  ]
  target_group_arn = module.nlb.blue_target_group_arn

  enable_xray_sidecar = var.enable_xray
  log_retention_days  = var.app_log_retention_days
}

module "jwt_public_key" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/secrets?ref=v1.0.0"

  name        = "${var.project_name}/service-b/jwt-public-key"
  environment = var.environment
  description = "RSA public key used by Service B to verify inbound JWTs from Service A"

  secret_string = var.jwt_public_key
}

module "database" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/rds?ref=v1.0.0"

  project_name = var.project_name
  
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids_list
  source_security_group_id   = module.ecs_service.task_security_group_id

  engine_version      = var.db_engine_version
  mysql_major_version = var.db_mysql_major_version
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  database_name       = var.db_database_name
  master_username     = var.db_master_username

  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot

  backup_retention_days   = var.db_backup_retention_days
  backup_schedule         = var.db_backup_schedule
  backup_copy_region      = var.db_backup_copy_region
  backup_copy_kms_key_arn = var.db_backup_copy_kms_key_arn

  # ARN of the SecretsManagerRDSMySQLRotationMultiUser Lambda
  rotation_lambda_arn = var.db_rotation_lambda_arn
  rotation_days       = var.db_rotation_days

  alarm_sns_topic_arns = var.db_alarm_sns_topic_arns
}

module "blue_green_deployment" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/codedeploy?ref=v1.0.0"

  project_name             = var.project_name
  ecs_cluster_name         = module.ecs_service.cluster_name
  ecs_service_name         = module.ecs_service.service_name

  prod_listener_arn = module.nlb.prod_tcp_listener_arn
  test_listener_arn = module.nlb.test_tcp_listener_arn

  blue_target_group_name   = module.nlb.blue_target_group_name
  green_target_group_name  = module.nlb.green_target_group_name

  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent15Minutes"

  alarm_names = []
}

module "sqs" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/sqs?ref=v1.0.0"

  project_name       = var.project_name
  kms_key_arn        = var.sqs_kms_key_arn
  producer_role_arn  = module.ecs_service.task_role_arn
  ses_sender_address = var.ses_sender_address

  lambda_s3_bucket  = var.lambda_s3_bucket
  lambda_s3_key     = var.lambda_s3_key

  log_retention_days   = var.app_log_retention_days
  alarm_sns_topic_arns = var.sqs_alarm_sns_topic_arns
}

# allow ECS tasks to reach AWS service APIs on port 443
resource "aws_vpc_security_group_ingress_rule" "ecs_to_endpoints" {
  security_group_id            = module.vpc.endpoint_security_group_id
  description                  = "Allow ECS tasks to reach AWS service APIs"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs_service.task_security_group_id
}