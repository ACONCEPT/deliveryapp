# Terraform Backend Configuration - S3 + DynamoDB
# This creates the infrastructure needed to store Terraform state remotely
# Run this FIRST before deploying the main infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Use local backend for the backend itself (chicken-and-egg problem)
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "delivery-app"
      Component   = "terraform-backend"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-${var.environment}"
    Description = "Terraform state storage"
  }
}

# Enable versioning to keep state history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable logging for audit trail
resource "aws_s3_bucket_logging" "terraform_state" {
  count  = var.enable_state_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs[0].id
  target_prefix = "state-access-logs/"
}

# S3 Bucket for access logs (optional)
resource "aws_s3_bucket" "terraform_state_logs" {
  count  = var.enable_state_logging ? 1 : 0
  bucket = "${var.project_name}-terraform-state-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-logs-${var.environment}"
    Description = "Terraform state access logs"
  }
}

# Lifecycle policy for logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  count  = var.enable_state_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing (Free Tier eligible)
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery for additional safety
  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-locks-${var.environment}"
    Description = "Terraform state locking"
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}