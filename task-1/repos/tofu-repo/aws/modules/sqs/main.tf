resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-email-dlq"
}

# unimplemented
resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
}

# unimplemented
resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-email-queue"
  redrive_policy = jsonencode({})
}

# unimplemented
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-email-worker"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-email-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "${var.project_name}-email-worker-sqs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
      ]
      Resource = [
        aws_sqs_queue.main.arn,
        aws_sqs_queue.dlq.arn,
      ]
    }]
  })
}

# unimplemented
resource "aws_iam_role_policy" "lambda_ses" {
  name = "${var.project_name}-email-worker-ses"
  role = aws_iam_role.lambda.id
}

# Write structured logs to the pre-created log group
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.project_name}-email-worker-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
    }]
  })
}

# unimplemented 
resource "aws_iam_role_policy" "lambda_kms" {
  name = "${var.project_name}-email-worker-kms"

  # allow lambda to use kms key
}

# X-Ray active tracing
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# unimplemented
resource "aws_lambda_function" "email_worker" {
  
}

# unimplemented
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = aws_sqs_queue.main.arn
  function_name                      = aws_lambda_function.email_worker.arn
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.project_name}-email-queue-depth"
  alarm_description   = "Email queue depth is high"
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.project_name}-email-dlq-depth"
  alarm_description   = "Messages are present in the email DLQ"
}

# unimplemented
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-email-worker-errors"
  alarm_description   = "Email worker is throwing errors"
}
