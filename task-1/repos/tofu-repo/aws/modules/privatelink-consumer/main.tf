resource "aws_security_group" "this" {
  name        = "${var.project_name}-privatelink-endpoint-sg"
  description = "Controls inbound access to the PrivateLink interface endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow ECS tasks to call the remote service via PrivateLink"
    from_port       = var.service_port
    to_port         = var.service_port
    protocol        = "tcp"
    security_groups = [var.ecs_task_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-privatelink-endpoint-sg"
  })
}

resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.vpc_id
  service_name        = var.provider_endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.this.id]
  private_dns_enabled = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-privatelink-endpoint"
  })
}
