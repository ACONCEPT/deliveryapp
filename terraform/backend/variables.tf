# Backend Configuration Variables

variable "aws_region" {
  description = "AWS region for backend resources"
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

variable "enable_state_logging" {
  description = "Enable access logging for Terraform state bucket"
  type        = bool
  default     = false
}

variable "enable_dynamodb_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB state lock table"
  type        = bool
  default     = true
}