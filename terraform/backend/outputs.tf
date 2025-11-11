# Backend Configuration Outputs

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config" {
  description = "Backend configuration block to use in infrastructure code"
  value       = <<-EOT

    Add this to your terraform/infra/main.tf file:

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "infra/terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      }
    }

    Or use backend config file (recommended):
    Create terraform/infra/backend.hcl with:

    bucket         = "${aws_s3_bucket.terraform_state.id}"
    key            = "infra/terraform.tfstate"
    region         = "${var.aws_region}"
    encrypt        = true
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"

    Then run: terraform init -backend-config=backend.hcl
  EOT
}

output "setup_complete" {
  description = "Setup completion message"
  value       = <<-EOT

    ========================================
    TERRAFORM BACKEND SETUP COMPLETE!
    ========================================

    Resources created:
    - S3 Bucket:      ${aws_s3_bucket.terraform_state.id}
    - DynamoDB Table: ${aws_dynamodb_table.terraform_locks.name}

    Features enabled:
    - ✓ Versioning (state history)
    - ✓ Encryption (AES256)
    - ✓ State locking (prevent conflicts)
    - ✓ Public access blocked
    ${var.enable_dynamodb_point_in_time_recovery ? "- ✓ Point-in-time recovery" : ""}

    Next steps:
    1. Navigate to infra directory: cd ../infra
    2. Copy backend config: terraform output -raw backend_config > backend-config.txt
    3. Follow the backend configuration instructions
    4. Initialize with backend: terraform init -backend-config=backend.hcl
    5. Deploy infrastructure: terraform apply

  EOT
}
