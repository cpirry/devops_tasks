locals {
  is_alb = var.lb_type == "alb"
  is_nlb = var.lb_type == "nlb"
}

resource "aws_security_group" "alb" {
  count = local.is_alb ? 1 : 0

  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP and HTTPS inbound from the public internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.test_port != null ? [1] : []
    content {
      description = "HTTPS test listener (blue/green deployments)"
      from_port   = var.test_port
      to_port     = var.test_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound to targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "nlb" {
  count = local.is_nlb ? 1 : 0

  name        = "${var.project_name}-nlb-sg"
  description = "Allow inbound on service port from within the VPC (PrivateLink endpoint ENIs)"
  vpc_id      = var.vpc_id

  ingress {
    description = "Service port from PrivateLink endpoint ENIs"
    from_port   = var.service_port
    to_port     = var.service_port
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr != null ? [var.vpc_cidr] : []
  }

  dynamic "ingress" {
    for_each = var.test_port != null ? [1] : []
    content {
      description = "Test port from PrivateLink endpoint ENIs (blue/green deployments)"
      from_port   = var.test_port
      to_port     = var.test_port
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr != null ? [var.vpc_cidr] : []
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-nlb-sg"
  })
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.lb_type}"
  load_balancer_type = var.lb_type
  internal           = local.is_nlb ? true : false
  subnets            = var.subnet_ids
  security_groups    = local.is_alb ? [aws_security_group.alb[0].id] : (local.is_nlb ? [aws_security_group.nlb[0].id] : [])

  enable_deletion_protection = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != null ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.project_name
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.lb_type}"
  })
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-tg-blue"
  port        = var.service_port
  protocol    = local.is_alb ? "HTTP" : "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    # healthchecks here
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-tg-green"
  port        = var.service_port
  protocol    = local.is_alb ? "HTTP" : "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    # healthchecks here
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP listener: redirect all traffic to HTTPS
resource "aws_lb_listener" "http" {
  count = local.is_alb ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# HTTPS listener, "Service A" "prod" traffic
# "prod" traffic = traffic for original app
resource "aws_lb_listener" "prod_https" {
  count = local.is_alb ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = var.tags
}

# HTTPS listener for test (green) traffic during blue/green deployments.
resource "aws_lb_listener" "test_https" {
  count = local.is_alb && var.test_port != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.test_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  tags = var.tags
}

# TCP listener, "Service A" "prod" traffic
# "prod" traffic = traffic for original app
resource "aws_lb_listener" "prod_tcp" {
  count = local.is_nlb ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.service_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = var.tags
}

# TCP listener for test (green) traffic during blue/green deployments.
resource "aws_lb_listener" "test_tcp" {
  count = local.is_nlb && var.test_port != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.test_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  count = local.is_alb && var.waf_web_acl_arn != null ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}

resource "aws_wafv2_web_acl" "alb" {
  count = local.is_alb && var.create_waf ? 1 : 0

  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "created" {
  count = local.is_alb && var.create_waf ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn
}

resource "aws_vpc_endpoint_service" "this" {
  count = local.is_nlb && var.create_endpoint_service ? 1 : 0

  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.this.arn]

  allowed_principals = var.endpoint_service_allowed_principals

  tags = merge(var.tags, {
    Name = "${var.project_name}-endpoint-service"
  })
}