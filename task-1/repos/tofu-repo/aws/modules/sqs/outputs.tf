output "queue_url" {
  description = "URL of the main SQS email queue"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN of the main SQS email queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Name of the main SQS email queue"
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "URL of the dead-letter queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "lambda_function_arn" {
  description = "ARN of the email worker Lambda function"
  value       = aws_lambda_function.email_worker.arn
}

output "lambda_function_name" {
  description = "Name of the email worker Lambda function"
  value       = aws_lambda_function.email_worker.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}
