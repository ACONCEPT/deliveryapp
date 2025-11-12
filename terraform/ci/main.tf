terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend configuration
  # S3 backend for storing Terraform state
  backend "s3" {
    bucket         = "delivery-app-terraform-state-dev-084374024444"
    key            = "ci/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "delivery-app-terraform-locks-dev"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "delivery-app"
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "ci"
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}
