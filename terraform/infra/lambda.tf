# Lambda Function for Backend API
# Uses AWS Lambda Web Adapter to run the existing Go HTTP server

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role-${var.environment}"

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
    Name = "${var.project_name}-lambda-role-${var.environment}"
  }
}

# Attach basic Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for VPC access (to connect to RDS)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets" {
  count = var.store_secrets_in_secrets_manager ? 1 : 0
  name  = "${var.project_name}-lambda-secrets-${var.environment}"
  role  = aws_iam_role.lambda.id

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

# IAM Policy for S3 uploads access
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3-${var.environment}"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}

# Security Group for Lambda (to access RDS)
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg-${var.environment}"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-lambda-sg-${var.environment}"
  }
}

# Update RDS security group to allow Lambda access
resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.database.id
  description              = "PostgreSQL from Lambda"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-backend-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-lambda-logs-${var.environment}"
  }
}

# Lambda Function
resource "aws_lambda_function" "backend" {
  function_name = "${var.project_name}-backend-${var.environment}"
  role          = aws_iam_role.lambda.arn

  # Deployment package (will be created by build script)
  filename         = var.lambda_deployment_package
  source_code_hash = filebase64sha256(var.lambda_deployment_package)

  handler = "bootstrap" # For Go custom runtime
  runtime = "provided.al2023" # Go requires custom runtime

  # Architecture (arm64 is cheaper and performs better)
  architectures = ["arm64"]

  # Memory and timeout configuration
  memory_size = var.lambda_memory_size # 512MB to 1024MB recommended
  timeout     = var.lambda_timeout # 30 seconds default, max 900

  # Environment variables
  environment {
    variables = {
      DATABASE_URL        = "postgres://${var.db_username}:${urlencode(var.db_password != "" ? var.db_password : random_password.db_password[0].result)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
      JWT_SECRET          = var.jwt_secret
      TOKEN_DURATION      = var.token_duration
      ENVIRONMENT         = var.environment
      MAPBOX_ACCESS_TOKEN = var.mapbox_access_token
      SERVER_PORT         = "8080" # Lambda Web Adapter expects this
      S3_UPLOADS_BUCKET   = aws_s3_bucket.uploads.bucket
      AWS_REGION_CUSTOM   = var.aws_region # AWS_REGION is reserved

      # AWS Lambda Web Adapter configuration
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
      RUST_LOG                = "info"
      READINESS_CHECK_PATH    = "/health"
      READINESS_CHECK_PORT    = "8080"
      REMOVE_BASE_PATH        = "/"
    }
  }

  # VPC Configuration (to access RDS)
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Lambda Layer for AWS Lambda Web Adapter
  layers = [
    "arn:aws:lambda:${var.aws_region}:753240598075:layer:LambdaAdapterLayerArm64:22" # Latest version for arm64
  ]

  tags = {
    Name = "${var.project_name}-backend-${var.environment}"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc
  ]
}

# Lambda Function URL (alternative to API Gateway for simple use cases)
resource "aws_lambda_function_url" "backend" {
  count              = var.use_lambda_function_url ? 1 : 0
  function_name      = aws_lambda_function.backend.function_name
  authorization_type = "NONE" # Public access

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 86400
  }
}

# S3 Bucket for uploads (menu item images, etc.)
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-uploads-${var.environment}"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy for public read access
resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.uploads.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.uploads]
}

# S3 Bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
