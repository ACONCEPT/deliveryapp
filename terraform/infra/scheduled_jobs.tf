# Scheduled Jobs using AWS EventBridge and Lambda
# Runs maintenance tasks for the delivery app

# IAM Role for Scheduled Jobs Lambda Functions
resource "aws_iam_role" "jobs_lambda" {
  name = "${var.project_name}-jobs-lambda-role-${var.environment}"

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
    Name = "${var.project_name}-jobs-lambda-role-${var.environment}"
  }
}

# Attach basic Lambda execution role
resource "aws_iam_role_policy_attachment" "jobs_lambda_basic" {
  role       = aws_iam_role.jobs_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC access for RDS connection
resource "aws_iam_role_policy_attachment" "jobs_lambda_vpc" {
  role       = aws_iam_role.jobs_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log Groups for each job
resource "aws_cloudwatch_log_group" "job_cancel_unconfirmed_orders" {
  name              = "/aws/lambda/${var.project_name}-job-cancel-unconfirmed-orders-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-job-cancel-unconfirmed-orders-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "job_cleanup_orphaned_menus" {
  name              = "/aws/lambda/${var.project_name}-job-cleanup-orphaned-menus-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-job-cleanup-orphaned-menus-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "job_archive_old_orders" {
  name              = "/aws/lambda/${var.project_name}-job-archive-old-orders-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-job-archive-old-orders-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "job_update_driver_availability" {
  name              = "/aws/lambda/${var.project_name}-job-update-driver-availability-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-job-update-driver-availability-logs-${var.environment}"
  }
}

# Lambda Function: Cancel Unconfirmed Orders
# Runs: Every 1 minute
resource "aws_lambda_function" "job_cancel_unconfirmed_orders" {
  function_name = "${var.project_name}-job-cancel-unconfirmed-orders-${var.environment}"
  role          = aws_iam_role.jobs_lambda.arn

  filename         = var.lambda_jobs_deployment_package
  source_code_hash = filebase64sha256(var.lambda_jobs_deployment_package)

  handler = "bootstrap"
  runtime = "provided.al2023"

  architectures = ["arm64"]

  memory_size = 256 # Jobs require less memory
  timeout     = 60  # 1 minute max

  environment {
    variables = {
      DATABASE_URL   = "postgres://${var.db_username}:${urlencode(var.db_password != "" ? var.db_password : random_password.db_password[0].result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
      JOB_NAME       = "cancel-unconfirmed-orders"
      ENVIRONMENT    = var.environment
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-job-cancel-unconfirmed-orders-${var.environment}"
    Job  = "cancel-unconfirmed-orders"
  }

  depends_on = [
    aws_cloudwatch_log_group.job_cancel_unconfirmed_orders,
    aws_iam_role_policy_attachment.jobs_lambda_basic,
    aws_iam_role_policy_attachment.jobs_lambda_vpc
  ]
}

# Lambda Function: Cleanup Orphaned Menus
# Runs: Daily at 2:00 AM UTC
resource "aws_lambda_function" "job_cleanup_orphaned_menus" {
  function_name = "${var.project_name}-job-cleanup-orphaned-menus-${var.environment}"
  role          = aws_iam_role.jobs_lambda.arn

  filename         = var.lambda_jobs_deployment_package
  source_code_hash = filebase64sha256(var.lambda_jobs_deployment_package)

  handler = "bootstrap"
  runtime = "provided.al2023"

  architectures = ["arm64"]

  memory_size = 256
  timeout     = 60

  environment {
    variables = {
      DATABASE_URL   = "postgres://${var.db_username}:${urlencode(var.db_password != "" ? var.db_password : random_password.db_password[0].result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
      JOB_NAME       = "cleanup-orphaned-menus"
      ENVIRONMENT    = var.environment
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-job-cleanup-orphaned-menus-${var.environment}"
    Job  = "cleanup-orphaned-menus"
  }

  depends_on = [
    aws_cloudwatch_log_group.job_cleanup_orphaned_menus,
    aws_iam_role_policy_attachment.jobs_lambda_basic,
    aws_iam_role_policy_attachment.jobs_lambda_vpc
  ]
}

# Lambda Function: Archive Old Orders
# Runs: Weekly on Sunday at 3:00 AM UTC
resource "aws_lambda_function" "job_archive_old_orders" {
  function_name = "${var.project_name}-job-archive-old-orders-${var.environment}"
  role          = aws_iam_role.jobs_lambda.arn

  filename         = var.lambda_jobs_deployment_package
  source_code_hash = filebase64sha256(var.lambda_jobs_deployment_package)

  handler = "bootstrap"
  runtime = "provided.al2023"

  architectures = ["arm64"]

  memory_size = 256
  timeout     = 120 # 2 minutes for larger dataset

  environment {
    variables = {
      DATABASE_URL   = "postgres://${var.db_username}:${urlencode(var.db_password != "" ? var.db_password : random_password.db_password[0].result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
      JOB_NAME       = "archive-old-orders"
      ENVIRONMENT    = var.environment
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-job-archive-old-orders-${var.environment}"
    Job  = "archive-old-orders"
  }

  depends_on = [
    aws_cloudwatch_log_group.job_archive_old_orders,
    aws_iam_role_policy_attachment.jobs_lambda_basic,
    aws_iam_role_policy_attachment.jobs_lambda_vpc
  ]
}

# Lambda Function: Update Driver Availability
# Runs: Every 5 minutes
resource "aws_lambda_function" "job_update_driver_availability" {
  function_name = "${var.project_name}-job-update-driver-availability-${var.environment}"
  role          = aws_iam_role.jobs_lambda.arn

  filename         = var.lambda_jobs_deployment_package
  source_code_hash = filebase64sha256(var.lambda_jobs_deployment_package)

  handler = "bootstrap"
  runtime = "provided.al2023"

  architectures = ["arm64"]

  memory_size = 256
  timeout     = 60

  environment {
    variables = {
      DATABASE_URL   = "postgres://${var.db_username}:${urlencode(var.db_password != "" ? var.db_password : random_password.db_password[0].result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
      JOB_NAME       = "update-driver-availability"
      ENVIRONMENT    = var.environment
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name = "${var.project_name}-job-update-driver-availability-${var.environment}"
    Job  = "update-driver-availability"
  }

  depends_on = [
    aws_cloudwatch_log_group.job_update_driver_availability,
    aws_iam_role_policy_attachment.jobs_lambda_basic,
    aws_iam_role_policy_attachment.jobs_lambda_vpc
  ]
}

# EventBridge Rule: Cancel Unconfirmed Orders (every 1 minute)
resource "aws_cloudwatch_event_rule" "cancel_unconfirmed_orders" {
  name                = "${var.project_name}-cancel-unconfirmed-orders-${var.environment}"
  description         = "Trigger cancel unconfirmed orders job every 1 minute"
  schedule_expression = var.enable_scheduled_jobs ? "rate(1 minute)" : null
  state               = var.enable_scheduled_jobs ? "ENABLED" : "DISABLED"

  tags = {
    Name = "${var.project_name}-cancel-unconfirmed-orders-rule-${var.environment}"
  }
}

# EventBridge Target for Cancel Unconfirmed Orders
resource "aws_cloudwatch_event_target" "cancel_unconfirmed_orders" {
  rule      = aws_cloudwatch_event_rule.cancel_unconfirmed_orders.name
  target_id = "lambda"
  arn       = aws_lambda_function.job_cancel_unconfirmed_orders.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "cancel_unconfirmed_orders" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_cancel_unconfirmed_orders.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cancel_unconfirmed_orders.arn
}

# EventBridge Rule: Cleanup Orphaned Menus (daily at 2 AM UTC)
resource "aws_cloudwatch_event_rule" "cleanup_orphaned_menus" {
  name                = "${var.project_name}-cleanup-orphaned-menus-${var.environment}"
  description         = "Trigger cleanup orphaned menus job daily at 2 AM UTC"
  schedule_expression = var.enable_scheduled_jobs ? "cron(0 2 * * ? *)" : null
  state               = var.enable_scheduled_jobs ? "ENABLED" : "DISABLED"

  tags = {
    Name = "${var.project_name}-cleanup-orphaned-menus-rule-${var.environment}"
  }
}

resource "aws_cloudwatch_event_target" "cleanup_orphaned_menus" {
  rule      = aws_cloudwatch_event_rule.cleanup_orphaned_menus.name
  target_id = "lambda"
  arn       = aws_lambda_function.job_cleanup_orphaned_menus.arn
}

resource "aws_lambda_permission" "cleanup_orphaned_menus" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_cleanup_orphaned_menus.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_orphaned_menus.arn
}

# EventBridge Rule: Archive Old Orders (weekly on Sunday at 3 AM UTC)
resource "aws_cloudwatch_event_rule" "archive_old_orders" {
  name                = "${var.project_name}-archive-old-orders-${var.environment}"
  description         = "Trigger archive old orders job weekly on Sunday at 3 AM UTC"
  schedule_expression = var.enable_scheduled_jobs ? "cron(0 3 ? * SUN *)" : null
  state               = var.enable_scheduled_jobs ? "ENABLED" : "DISABLED"

  tags = {
    Name = "${var.project_name}-archive-old-orders-rule-${var.environment}"
  }
}

resource "aws_cloudwatch_event_target" "archive_old_orders" {
  rule      = aws_cloudwatch_event_rule.archive_old_orders.name
  target_id = "lambda"
  arn       = aws_lambda_function.job_archive_old_orders.arn
}

resource "aws_lambda_permission" "archive_old_orders" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_archive_old_orders.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.archive_old_orders.arn
}

# EventBridge Rule: Update Driver Availability (every 5 minutes)
resource "aws_cloudwatch_event_rule" "update_driver_availability" {
  name                = "${var.project_name}-update-driver-availability-${var.environment}"
  description         = "Trigger update driver availability job every 5 minutes"
  schedule_expression = var.enable_scheduled_jobs ? "rate(5 minutes)" : null
  state               = var.enable_scheduled_jobs ? "ENABLED" : "DISABLED"

  tags = {
    Name = "${var.project_name}-update-driver-availability-rule-${var.environment}"
  }
}

resource "aws_cloudwatch_event_target" "update_driver_availability" {
  rule      = aws_cloudwatch_event_rule.update_driver_availability.name
  target_id = "lambda"
  arn       = aws_lambda_function.job_update_driver_availability.arn
}

resource "aws_lambda_permission" "update_driver_availability" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_update_driver_availability.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.update_driver_availability.arn
}