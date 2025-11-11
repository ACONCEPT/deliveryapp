# Lambda Function for Database Migrations
# This Lambda function runs database migrations against the RDS instance
# It can be invoked manually via AWS CLI or triggered by deployment pipelines

# IAM Role for Migration Lambda
resource "aws_iam_role" "migrate_lambda" {
  name = "${var.project_name}-migrate-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-migrate-lambda-role-${var.environment}"
  }
}

# Attach basic Lambda execution role
resource "aws_iam_role_policy_attachment" "migrate_lambda_basic" {
  role       = aws_iam_role.migrate_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution role (to access RDS in private subnet)
resource "aws_iam_role_policy_attachment" "migrate_lambda_vpc" {
  role       = aws_iam_role.migrate_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM Policy for Migration Lambda Secrets Manager access
resource "aws_iam_role_policy" "migrate_lambda_secrets" {
  count = var.store_secrets_in_secrets_manager ? 1 : 0
  name  = "${var.project_name}-migrate-lambda-secrets-${var.environment}"
  role  = aws_iam_role.migrate_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials[0].arn
      }
    ]
  })
}

# CloudWatch Log Group for Migration Lambda
resource "aws_cloudwatch_log_group" "migrate_lambda" {
  name              = "/aws/lambda/${var.project_name}-migrate-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-migrate-lambda-logs-${var.environment}"
  }
}

# Migration Lambda Function
resource "aws_lambda_function" "migrate" {
  function_name = "${var.project_name}-migrate-${var.environment}"
  role          = aws_iam_role.migrate_lambda.arn

  # Deployment package (will be created by build script)
  filename         = var.migrate_lambda_deployment_package
  source_code_hash = fileexists(var.migrate_lambda_deployment_package) ? filebase64sha256(var.migrate_lambda_deployment_package) : null

  handler = "bootstrap" # For Go custom runtime
  runtime = "provided.al2023" # Go requires custom runtime

  # Architecture (arm64 is cheaper and performs better)
  architectures = ["arm64"]

  # Memory and timeout configuration
  # Migrations might take longer, so we give it more time
  memory_size = 512  # 512MB should be sufficient
  timeout     = 300  # 5 minutes max

  # Environment variables
  environment {
    variables = var.store_secrets_in_secrets_manager ? {
      SECRET_ARN = aws_secretsmanager_secret.db_credentials[0].arn
    } : {
      DATABASE_URL = "postgres://${var.db_username}:${var.db_password != "" ? var.db_password : random_password.db_password[0].result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
    }
  }

  # VPC Configuration (to access RDS in private subnet)
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-migrate-lambda-${var.environment}"
  }

  depends_on = [
    aws_cloudwatch_log_group.migrate_lambda,
    aws_iam_role_policy_attachment.migrate_lambda_basic,
    aws_iam_role_policy_attachment.migrate_lambda_vpc
  ]

  lifecycle {
    ignore_changes = [
      source_code_hash, # Allow manual updates during development
      filename
    ]
  }
}

# Lambda Invocation Permission (for manual invocation)
# This allows anyone with the right IAM permissions to invoke the function
resource "aws_lambda_permission" "migrate_invoke" {
  count = var.allow_migrate_lambda_invocation ? 1 : 0

  statement_id  = "AllowInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.migrate.function_name
  principal     = "*"

  # Optionally restrict to specific principals or conditions
  # For production, you should restrict this to specific IAM roles/users
}

# CloudWatch Event Rule for scheduled migrations (optional)
# Uncomment if you want to run migrations on a schedule
# resource "aws_cloudwatch_event_rule" "migrate_schedule" {
#   name                = "${var.project_name}-migrate-schedule-${var.environment}"
#   description         = "Scheduled trigger for database migrations"
#   schedule_expression = "rate(1 day)" # Run daily
#
#   tags = {
#     Name = "${var.project_name}-migrate-schedule-${var.environment}"
#   }
# }
#
# resource "aws_cloudwatch_event_target" "migrate_schedule" {
#   rule      = aws_cloudwatch_event_rule.migrate_schedule.name
#   target_id = "MigrateLambda"
#   arn       = aws_lambda_function.migrate.arn
#
#   input = jsonencode({
#     action = "status" # Run status check only, not full migration
#   })
# }
#
# resource "aws_lambda_permission" "allow_cloudwatch" {
#   statement_id  = "AllowExecutionFromCloudWatch"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.migrate.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.migrate_schedule.arn
# }
