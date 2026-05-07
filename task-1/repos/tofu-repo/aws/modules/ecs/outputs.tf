output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the latest active task definition revision"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family name of the task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_security_group_id" {
  description = "ID of the security group attached to ECS tasks. Reference this in other security group ingress rules"
  value       = aws_security_group.tasks.id
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the ECS task execution IAM role"
  value       = aws_iam_role.execution.name
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the ECS task IAM role"
  value       = aws_iam_role.task.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for this service"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.arn
}
