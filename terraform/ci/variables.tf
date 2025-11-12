# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "delivery-app"
}

# GitHub Configuration
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "delivery_app"
}

variable "github_branches" {
  description = "List of GitHub branches allowed to assume the role"
  type        = list(string)
  default     = ["main", "develop"]
}

# Permissions Configuration
variable "enable_lambda_deployment" {
  description = "Allow GitHub Actions to deploy Lambda functions"
  type        = bool
  default     = true
}

variable "enable_s3_deployment" {
  description = "Allow GitHub Actions to deploy to S3 (frontend)"
  type        = bool
  default     = true
}

variable "enable_cloudfront_invalidation" {
  description = "Allow GitHub Actions to invalidate CloudFront cache"
  type        = bool
  default     = true
}

variable "enable_migration_lambda" {
  description = "Allow GitHub Actions to invoke migration Lambda"
  type        = bool
  default     = true
}

variable "enable_ecr_push" {
  description = "Allow GitHub Actions to push Docker images to ECR"
  type        = bool
  default     = false
}

variable "enable_terraform_state_read" {
  description = "Allow GitHub Actions to read Terraform state"
  type        = bool
  default     = true
}
