resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_iam_role" "execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow the execution role to read secrets from Secrets Manager at container start
resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  name = "${var.project_name}-execution-read-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.secret_arns
    }]
  })
}

resource "aws_iam_role" "task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "task_custom" {
  # attach any custom task policies
}

# X-Ray daemon write permissions
resource "aws_iam_role_policy_attachment" "task_xray" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_security_group" "tasks" {
  name        = "${var.project_name}-tasks-sg"
  description = "Controls inbound access to ECS tasks"
  vpc_id      = var.vpc_id

  # Inbound is controlled via ingress rules defined by the caller
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tasks-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "tasks" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  security_group_id            = aws_security_group.tasks.id
  description                  = each.value.description
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.protocol
  referenced_security_group_id = lookup(each.value, "source_security_group_id", null)
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
}

locals {
  container_definitions = concat(
    [
      {
        name      = var.container_name
        image     = var.container_image
        essential = true
        portMappings = [{
          containerPort = var.container_port
          protocol      = "tcp"
        }]
        environment = var.environment_variables
        secrets = [
          for secret in var.secret_mappings : {
            name      = secret.env_var
            valueFrom = secret.secret_arn
          }
        ]
        logConfiguration = {
          # log configuration to write to log group
          }
        }
        healthCheck = {
          # healthcheck configuration
        }
      }
    ],
    var.enable_xray_sidecar ? [{
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = false
      portMappings = [{
        containerPort = 2000
        protocol      = "udp"
      }]
      logConfiguration = {
        # log configuration to write to log group
        }
      }
    }] : []
  )
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(local.container_definitions)

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                               = var.service_name
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = var.health_check_grace_period
  force_new_deployment               = true
  enable_execute_command             = false

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    # allow external CI/CD pipelines to manage task definition revisions
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "this" {
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks
}

# target tracking — request count per target (for Service A)
resource "aws_appautoscaling_policy" "alb_request_count" {
  count = var.scaling_policy_type == "alb_request_count" ? 1 : 0

  name               = "${var.project_name}-scale-alb-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
  }
}

# target tracking — average CPU utilisation (for Service B)
resource "aws_appautoscaling_policy" "cpu" {
  count = var.scaling_policy_type == "cpu" ? 1 : 0

  name               = "${var.project_name}-scale-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}