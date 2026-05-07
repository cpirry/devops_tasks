project_name = "task1"

target_account_id     = "444444444444"
target_account_region = "eu-west-1"
environment           = "staging"

state_account_id     = "121212121212"
state_account_region = "eu-west-1"

consumer_account_id = "333333333333"

# vpc
vpc_cidr                   = "10.11.0.0/16"
private_subnet_cidrs       = ["10.11.3.0/24", "10.11.4.0/24"]
create_nat_gateway         = false
create_s3_gateway_endpoint = true

# ecs
desired_count          = 2
min_tasks              = 2
max_tasks              = 4
scaling_target_value   = 70
task_cpu               = 256
task_memory            = 512
service_port           = 8001
test_port              = 8002
enable_xray            = true
app_log_retention_days = 30
image_name             = "svc-b"
image_tag              = "321"

# database
db_engine_version          = "8.0.36"
db_mysql_major_version     = "8.0"
db_instance_class          = "db.t3.medium"
db_allocated_storage       = 20
db_database_name           = "my-app"
db_master_username         = "admin"
db_multi_az                = true
db_deletion_protection     = true
db_skip_final_snapshot     = false
db_backup_retention_days   = 14
db_backup_schedule         = ""
db_backup_copy_region      = ""
db_backup_copy_kms_key_arn = ""
db_rotation_lambda_arn     = ""
db_rotation_days           = 30
db_alarm_sns_topic_arns    = []
sqs_alarm_sns_topic_arns   = []
