project_name = "task1"

target_account_id     = "333333333333"
target_account_region = "eu-west-1"
environment           = "staging"

state_account_id     = "121212121212"
state_account_region = "eu-west-1"

# vpc
vpc_cidr                   = "10.1.0.0/16"
public_subnet_cidrs        = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs       = ["10.1.3.0/24", "10.1.4.0/24"]
create_nat_gateway         = true
create_s3_gateway_endpoint = true
create_waf                 = false

# dns
app_url = ""
spa_url = ""
zone_id = ""

# ecs
desired_count          = 2
min_tasks              = 2
max_tasks              = 4
scaling_target_value   = 1000
task_cpu               = 256
task_memory            = 512
service_port           = 8000
test_port              = 8443
enable_xray            = true
app_log_retention_days = 30
image_name             = "svc-a"
image_tag              = "123"

# provider
provider_service_port = 8001
