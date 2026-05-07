output "lb_id" {
  description = "ID of the load balancer"
  value       = aws_lb.this.id
}

output "lb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.this.arn
}

output "lb_arn_suffix" {
  description = "ARN suffix of the load balancer"
  value       = aws_lb.this.arn_suffix
}

output "lb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "lb_zone_id" {
  description = "Hosted zone ID of the load balancer"
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = var.lb_type == "alb" ? aws_security_group.alb[0].id : null
}

output "nlb_security_group_id" {
  description = "Security group ID of the NLB"
  value       = var.lb_type == "nlb" ? aws_security_group.nlb[0].id : null
}

output "blue_target_group_arn" {
  description = "ARN of the blue (prod) target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the green (test) target group"
  value       = aws_lb_target_group.green.arn
}

output "blue_target_group_arn_suffix" {
  description = "ARN suffix of the blue target group"
  value       = aws_lb_target_group.blue.arn_suffix
}

output "blue_target_group_name" {
  description = "Name of the blue target group "
  value       = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  description = "Name of the green target group"
  value       = aws_lb_target_group.green.name
}

output "prod_https_listener_arn" {
  description = "ARN of the HTTPS prod listener"
  value       = var.lb_type == "alb" ? aws_lb_listener.prod_https[0].arn : null
}

output "test_https_listener_arn" {
  description = "ARN of the HTTPS test listener"
  value       = var.lb_type == "alb" && var.test_port != null ? aws_lb_listener.test_https[0].arn : null
}

output "prod_tcp_listener_arn" {
  description = "ARN of the TCP prod listener"
  value       = var.lb_type == "nlb" ? aws_lb_listener.prod_tcp[0].arn : null
}

output "test_tcp_listener_arn" {
  description = "ARN of the TCP test listener"
  value       = var.lb_type == "nlb" && var.test_port != null ? aws_lb_listener.test_tcp[0].arn : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.create_waf ? aws_wafv2_web_acl.alb[0].arn : ""
}

output "endpoint_service_name" {
  description = "Name of the VPC Endpoint Service"
  value       = var.create_endpoint_service ? aws_vpc_endpoint_service.this[0].service_name : ""
}

output "endpoint_service_id" {
  description = "ID of the VPC Endpoint Service"
  value       = var.create_endpoint_service ? aws_vpc_endpoint_service.this[0].id : ""
}

output "autoscaling_resource_label" {
  description = "Autoscaling resource label"
  value = var.lb_type == "alb" ? "${aws_lb.this.arn_suffix}/${aws_lb_target_group.blue.arn_suffix}" : null
}
