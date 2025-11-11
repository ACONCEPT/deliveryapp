# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address (hostname only)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "database_username" {
  description = "Database master username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "database_url" {
  description = "PostgreSQL connection string (full DATABASE_URL)"
  value       = "postgres://${var.db_username}:${var.db_password != "" ? var.db_password : random_password.db_password[0].result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
  sensitive   = true
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.backend.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.backend.arn
}

output "lambda_function_url" {
  description = "Lambda function URL (if enabled)"
  value       = var.use_lambda_function_url ? aws_lambda_function_url.backend[0].function_url : "Not enabled"
}

# Migration Lambda Outputs
output "migrate_lambda_function_name" {
  description = "Migration Lambda function name"
  value       = aws_lambda_function.migrate.function_name
}

output "migrate_lambda_function_arn" {
  description = "Migration Lambda function ARN"
  value       = aws_lambda_function.migrate.arn
}

output "migrate_lambda_invoke_command" {
  description = "AWS CLI command to invoke migration Lambda"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.migrate.function_name} --payload '{\"action\":\"migrate\"}' --region ${var.aws_region} /tmp/migrate-response.json && cat /tmp/migrate-response.json"
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_custom_domain_url" {
  description = "API custom domain URL (if configured)"
  value       = var.api_custom_domain != "" ? "https://${var.api_custom_domain}" : "Not configured"
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_custom_domain_url" {
  description = "Frontend custom domain URL (if configured)"
  value       = var.frontend_custom_domain != "" ? "https://${var.frontend_custom_domain}" : "Not configured"
}

# S3 Outputs
output "frontend_s3_bucket" {
  description = "Frontend S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "uploads_s3_bucket" {
  description = "Uploads S3 bucket name"
  value       = aws_s3_bucket.uploads.id
}

output "uploads_s3_url" {
  description = "Uploads S3 bucket URL"
  value       = "https://${aws_s3_bucket.uploads.bucket_regional_domain_name}"
}

# Secrets Manager Outputs
output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN for database credentials"
  value       = var.store_secrets_in_secrets_manager ? aws_secretsmanager_secret.db_credentials[0].arn : "Not enabled"
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# Application URLs
output "application_urls" {
  description = "Important application URLs"
  value = {
    frontend_url = var.frontend_custom_domain != "" ? "https://${var.frontend_custom_domain}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
    backend_api_url = var.api_custom_domain != "" ? "https://${var.api_custom_domain}" : aws_apigatewayv2_api.main.api_endpoint
    uploads_url = "https://${aws_s3_bucket.uploads.bucket_regional_domain_name}"
  }
}

# Scheduled Jobs Outputs
output "scheduled_jobs" {
  description = "Scheduled jobs status and information"
  value = {
    enabled = var.enable_scheduled_jobs
    jobs = {
      cancel_unconfirmed_orders = {
        function_name = aws_lambda_function.job_cancel_unconfirmed_orders.function_name
        schedule      = "Every 1 minute"
        description   = "Cancel orders not confirmed by vendors within 30 minutes"
      }
      cleanup_orphaned_menus = {
        function_name = aws_lambda_function.job_cleanup_orphaned_menus.function_name
        schedule      = "Daily at 2:00 AM UTC"
        description   = "Remove menus not linked to restaurants (older than 30 days)"
      }
      archive_old_orders = {
        function_name = aws_lambda_function.job_archive_old_orders.function_name
        schedule      = "Weekly on Sunday at 3:00 AM UTC"
        description   = "Mark old delivered/cancelled orders as inactive (older than 90 days)"
      }
      update_driver_availability = {
        function_name = aws_lambda_function.job_update_driver_availability.function_name
        schedule      = "Every 5 minutes"
        description   = "Mark inactive drivers as unavailable (no update in 30 minutes)"
      }
    }
  }
}

# Next Steps
output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT

    ========================================
    DEPLOYMENT SUCCESSFUL!
    ========================================

    1. DATABASE SETUP:
       - Connect to RDS: psql "${aws_db_instance.postgres.endpoint}/${var.db_name}" -U ${var.db_username}
       - Run schema migrations from your local machine or Lambda

    2. FRONTEND DEPLOYMENT:
       - Build Flutter web app: cd frontend && flutter build web
       - Upload to S3: aws s3 sync build/web/ s3://${aws_s3_bucket.frontend.id}/
       - Invalidate CloudFront cache: aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths "/*"

    3. BACKEND DEPLOYMENT:
       - Build API Lambda package: ./terraform/scripts/build-lambda.sh
       - Build jobs Lambda package: ./terraform/scripts/build-jobs-lambda.sh
       - Deploy: terraform apply (will detect changes and redeploy)

    4. ACCESS YOUR APPLICATION:
       - Frontend: ${var.frontend_custom_domain != "" ? "https://${var.frontend_custom_domain}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"}
       - Backend API: ${var.api_custom_domain != "" ? "https://${var.api_custom_domain}" : aws_apigatewayv2_api.main.api_endpoint}
       - Health Check: ${aws_apigatewayv2_api.main.api_endpoint}/health

    5. MONITORING:
       - API Lambda Logs: aws logs tail /aws/lambda/${aws_lambda_function.backend.function_name} --follow
       - API Gateway Logs: aws logs tail /aws/apigateway/${var.project_name}-${var.environment} --follow
       - Jobs Logs: aws logs tail /aws/lambda/${aws_lambda_function.job_cancel_unconfirmed_orders.function_name} --follow

    6. SCHEDULED JOBS:
       - Status: ${var.enable_scheduled_jobs ? "ENABLED" : "DISABLED"}
       - View all jobs: terraform output scheduled_jobs
       - Disable jobs: Set enable_scheduled_jobs = false in terraform.tfvars

    EOT
}
