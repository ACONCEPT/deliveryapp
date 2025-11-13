# GitHub Actions IAM Role Outputs

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_oidc_provider_url" {
  description = "URL of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.url
}

output "allowed_repositories" {
  description = "List of GitHub repositories and branches allowed to assume this role"
  value = [
    for branch in var.github_branches :
    "${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"
  ]
}

output "enabled_permissions" {
  description = "List of enabled permissions for GitHub Actions"
  value = {
    lambda_deployment         = var.enable_lambda_deployment
    s3_deployment            = var.enable_s3_deployment
    cloudfront_invalidation  = var.enable_cloudfront_invalidation
    migration_lambda         = var.enable_migration_lambda
    ecr_push                 = var.enable_ecr_push
    terraform_state_read     = var.enable_terraform_state_read
    terraform_infrastructure = var.enable_terraform_infrastructure
  }
}

output "github_actions_setup_instructions" {
  description = "Instructions for setting up GitHub Actions"
  value       = <<-EOT

  ========================================
  GITHUB ACTIONS SETUP COMPLETE!
  ========================================

  1. ADD GITHUB SECRETS:
     Go to your repository settings → Secrets and variables → Actions

     Add the following secrets:
     - AWS_REGION: ${var.aws_region}
     - AWS_ROLE_ARN: ${aws_iam_role.github_actions.arn}

  2. CONFIGURE WORKFLOW:
     In your .github/workflows/*.yml files, add:

     ```yaml
     name: Deploy
     on:
       push:
         branches: [${join(", ", var.github_branches)}]

     permissions:
       id-token: write   # Required for OIDC
       contents: read    # Required for checkout

     jobs:
       deploy:
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v4

           - name: Configure AWS Credentials
             uses: aws-actions/configure-aws-credentials@v4
             with:
               role-to-assume: $${{ secrets.AWS_ROLE_ARN }}
               aws-region: $${{ secrets.AWS_REGION }}
               role-session-name: GitHubActions-$${{ github.run_id }}

           - name: Verify AWS Identity
             run: aws sts get-caller-identity
     ```

  3. ENABLED PERMISSIONS:
     - Lambda Deployment: ${var.enable_lambda_deployment}
     - S3 Frontend Deployment: ${var.enable_s3_deployment}
     - CloudFront Invalidation: ${var.enable_cloudfront_invalidation}
     - Migration Lambda Invocation: ${var.enable_migration_lambda}
     - ECR Push: ${var.enable_ecr_push}
     - Terraform State Management: ${var.enable_terraform_state_read}
     - Terraform Infrastructure Management: ${var.enable_terraform_infrastructure}

  4. ALLOWED BRANCHES:
     ${join("\n     ", [for branch in var.github_branches : "- ${branch}"])}

  5. SECURITY NOTES:
     - No long-lived AWS credentials needed
     - Credentials are short-lived (15 minutes by default)
     - Only specified branches can assume the role
     - Role can only be assumed from ${var.github_org}/${var.github_repo}

  6. TESTING:
     Push to an allowed branch and check the Actions tab in GitHub

  EOT
}
