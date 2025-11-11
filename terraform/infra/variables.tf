# General Variables
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1" # Free Tier available in all regions
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

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# RDS Configuration
variable "db_instance_class" {
  description = "RDS instance class (Free Tier: db.t3.micro or db.t4g.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (Free Tier: up to 20GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "delivery_app"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "delivery_user"
}

variable "db_password" {
  description = "Database master password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_backup_retention_days" {
  description = "Number of days to retain backups (Free Tier: up to 7 days)"
  type        = number
  default     = 7
}

variable "db_publicly_accessible" {
  description = "Make database publicly accessible (set to false for production)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS (set to false for production)"
  type        = bool
  default     = true
}

variable "store_secrets_in_secrets_manager" {
  description = "Store database credentials in AWS Secrets Manager"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_deployment_package" {
  description = "Path to Lambda deployment package (zip file)"
  type        = string
  default     = "../../build/lambda-deployment.zip"
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB (128-10240)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds (max 900)"
  type        = number
  default     = 30
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for Lambda in days"
  type        = number
  default     = 7
}

variable "use_lambda_function_url" {
  description = "Enable Lambda Function URL (alternative to API Gateway)"
  type        = bool
  default     = false
}

# API Gateway Configuration
variable "api_gateway_timeout_ms" {
  description = "API Gateway integration timeout in milliseconds (max 30000)"
  type        = number
  default     = 29000
}

variable "api_gateway_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 5000
}

variable "api_gateway_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 10000
}

variable "api_gateway_log_retention_days" {
  description = "CloudWatch log retention for API Gateway in days"
  type        = number
  default     = 7
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

variable "api_custom_domain" {
  description = "Custom domain name for API (leave empty to use default)"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for API custom domain (required if api_custom_domain is set)"
  type        = string
  default     = ""
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100 for Free Tier: US, Canada, Europe)"
  type        = string
  default     = "PriceClass_100"
}

variable "frontend_custom_domain" {
  description = "Custom domain name for frontend (leave empty to use CloudFront domain)"
  type        = string
  default     = ""
}

variable "frontend_acm_certificate_arn" {
  description = "ACM certificate ARN for frontend custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "cloudfront_logs_retention_days" {
  description = "Number of days to retain CloudFront logs"
  type        = number
  default     = 30
}

# Application Configuration
variable "jwt_secret" {
  description = "JWT secret for token signing (at least 32 characters)"
  type        = string
  sensitive   = true
}

variable "token_duration" {
  description = "JWT token duration in hours"
  type        = number
  default     = 72
}

variable "mapbox_access_token" {
  description = "Mapbox access token for distance calculations"
  type        = string
  sensitive   = true
  default     = ""
}

variable "backend_port" {
  description = "Backend server port (Lambda Web Adapter expects 8080)"
  type        = number
  default     = 8080
}

# Scheduled Jobs Configuration
variable "enable_scheduled_jobs" {
  description = "Enable scheduled jobs (EventBridge rules)"
  type        = bool
  default     = true
}

variable "lambda_jobs_deployment_package" {
  description = "Path to Lambda jobs deployment package (zip file)"
  type        = string
  default     = "../../build/lambda-jobs-deployment.zip"
}

# Migration Lambda Configuration
variable "migrate_lambda_deployment_package" {
  description = "Path to migration Lambda deployment package (zip file)"
  type        = string
  default     = "../../build/migrate-lambda.zip"
}

variable "allow_migrate_lambda_invocation" {
  description = "Allow migration Lambda to be invoked (for development)"
  type        = bool
  default     = true
}
