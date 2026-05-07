data "terraform_remote_state" "service_b" {
  backend = "s3"
  config = {
    bucket   = "my-app-tofu-state"
    key      = "service-b/${var.environment}/tofu.tfstate"
    region   = var.state_account_region
    role_arn = "arn:aws:iam::${var.state_account_id}:role/read-tofu-states"
  }
}

locals {
  provider_endpoint_service_name = data.terraform_remote_state.service_b.outputs.endpoint_service_name
}

module "vpc" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/vpc?ref=v1.0.0"

  project_name         = var.project_name
  aws_region           = var.target_account_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = ["${var.target_account_region}a", "${var.target_account_region}b"]
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  create_public_subnets       = true
  create_nat_gateway          = var.create_nat_gateway
  interface_endpoint_services = ["ecr.api", "ecr.dkr", "logs", "monitoring", "secretsmanager"]
  create_s3_gateway_endpoint  = var.create_s3_gateway_endpoint
}

module "alb_cert" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/acm?ref=v1.0.0"

  domain_name = var.app_url
  zone_id     = var.zone_id
}

module "alb" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/load-balancer?ref=v1.0.0"

  project_name    = var.project_name
  lb_type         = "alb"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids_list
  service_port    = var.service_port
  test_port       = var.test_port

  certificate_arn = module.tls_cert.certificate_arn
  create_waf      = var.create_waf

  enable_deletion_protection = true
}

module "jwt_private_key" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/secrets?ref=v1.0.0"

  name        = "${var.project_name}/service-a/jwt-private-key"
  environment = var.environment
  description = "RSA private key used by Service A to sign JWTs issued to Service B"

  secret_string = var.jwt_private_key
}

resource "aws_kms_key" "spa" {
  description             = "KMS key for SPA S3 bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

module "spa_bucket" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/s3?ref=v1.0.0"

  s3_bucket_name = "${var.project_name}-spa"
  kms_key_id     = aws_kms_key.spa.arn

  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

module "cloudfront_cert" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/acm?ref=v1.0.0"

  providers = {
    aws = aws.us_east_1
  }

  domain_name = var.spa_url
  zone_id     = var.zone_id
}

module "cloudfront" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/cloudfront?ref=v1.0.0"

  s3_bucket_name        = module.spa_bucket.bucket_name
  s3_bucket_domain_name = module.spa_bucket.bucket_regional_domain_name
  domain_aliases        = [var.spa_url]
  acm_certificate_arn   = module.cloudfront_cert.certificate_arn
  description           = "${var.project_name} SPA"
  price_class           = "PriceClass_100"
}

module "ecs_service" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/ecs?ref=v1.0.0"

  project_name     = var.project_name

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids_list

  cluster_name     = "${var.project_name}-service-a-cluster"
  service_name     = "${var.project_name}-service-a"

  container_name   = "${var.project_name}-service-container"
  container_image  = "${var.target_account_id}.dkr.ecr.${var.target_account_region}.amazonaws.com/${var.image_name}:${var.image_tag}"
  container_port   = var.service_port
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory

  min_tasks     = var.min_tasks
  max_tasks     = var.max_tasks
  desired_count = var.desired_count

  scaling_policy_type  = "alb_request_count"
  scaling_target_value = var.scaling_target_value
  alb_resource_label   = module.alb.autoscaling_resource_label
  target_group_arn     = module.alb.blue_target_group_arn

  environment_variables = [
    { 
      name = "SERVICE_B_URL", 
      value = "http://${module.service_b_endpoint.dns_name}:${var.provider_service_port}" 
    }
  ]

  secret_arns = [
    module.jwt_private_key.secret_arn
  ]
  secret_mappings = [
    {
      env_var    = "JWT_PRIVATE_KEY"
      secret_arn = module.jwt_private_key.secret_arn
    }
  ]

  health_check = {
    # healthcheck
  }

  ingress_rules = [
    {
      description              = "Allow TCP on service port from ALB"
      from_port                = var.service_port
      to_port                  = var.service_port
      protocol                 = "tcp"
      source_security_group_id = module.alb.alb_security_group_id
    }
  ]

  enable_xray_sidecar = var.enable_xray
  log_retention_days  = var.app_log_retention_days
}

module "blue_green_deployment" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/codedeploy?ref=v1.0.0"

  project_name             = var.project_name
  ecs_cluster_name         = module.ecs_service.cluster_name
  ecs_service_name         = module.ecs_service.service_name

  prod_listener_arn = module.alb.prod_https_listener_arn
  test_listener_arn = module.alb.test_https_listener_arn

  blue_target_group_name   = module.alb.blue_target_group_name
  green_target_group_name  = module.alb.green_target_group_name

  deployment_config_name   = "CodeDeployDefault.ECSCanary10Percent15Minutes"

  alarm_names = []
}

# create an interface endpoint in Account A that connects to Account B
module "service_b_endpoint" {
  source = "git::https://github.com/org/tofu-repo.git//aws/modules/privatelink-consumer?ref=v1.0.0"

  project_name                   = var.project_name
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnet_ids_list
  provider_endpoint_service_name = local.provider_endpoint_service_name
  ecs_task_security_group_id     = module.ecs_service.task_security_group_id
  service_port                   = var.provider_service_port
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