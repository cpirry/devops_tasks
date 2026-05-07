project_name = "task1"

target_account_id     = "555555555555"
target_account_region = "eu-west-1"
environment           = "prod"

state_account_id     = "121212121212"
state_account_region = "eu-west-1"

# vpc
vpc_cidr                   = "10.2.0.0/16"
public_subnet_cidrs        = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs       = ["10.2.3.0/24", "10.2.4.0/24"]
create_nat_gateway         = true
create_s3_gateway_endpoint = true
create_waf                 = true

# dns
app_url = "api.my-app.com"
spa_url = "my-app.com"
zone_id = ""

# ecs
desired_count          = 2
min_tasks              = 2
max_tasks              = 8
scaling_target_value   = 1000
task_cpu               = 512
task_memory            = 1024
service_port           = 8000
test_port              = 8443
enable_xray            = true
app_log_retention_days = 90
image_name             = "svc-a"
# image_tag passed at deploy time

# provider
provider_service_port = 8001
