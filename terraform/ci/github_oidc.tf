# GitHub OIDC Provider
# This allows GitHub Actions to authenticate with AWS without long-lived credentials
# Reference: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's OIDC thumbprints
  # These are the SHA1 fingerprints of the root CA certificates used by GitHub
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "${var.project_name}-github-oidc-${var.environment}"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name        = "${var.project_name}-github-actions-${var.environment}"
  description = "Role for GitHub Actions to deploy application resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow assuming role from specific repo and branches
            "token.actions.githubusercontent.com:sub" = [
              for branch in var.github_branches :
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-role-${var.environment}"
  }
}

# IAM Policy for Lambda Deployment
resource "aws_iam_policy" "lambda_deployment" {
  count       = var.enable_lambda_deployment ? 1 : 0
  name        = "${var.project_name}-github-lambda-deployment-${var.environment}"
  description = "Allow GitHub Actions to deploy Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:ListTags",
          "lambda:PublishVersion"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*-${var.environment}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_deployment" {
  count      = var.enable_lambda_deployment ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.lambda_deployment[0].arn
}

# IAM Policy for S3 Frontend Deployment
resource "aws_iam_policy" "s3_deployment" {
  count       = var.enable_s3_deployment ? 1 : 0
  name        = "${var.project_name}-github-s3-deployment-${var.environment}"
  description = "Allow GitHub Actions to deploy frontend to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project_name}-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_deployment" {
  count      = var.enable_s3_deployment ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_deployment[0].arn
}

# IAM Policy for CloudFront Invalidation
resource "aws_iam_policy" "cloudfront_invalidation" {
  count       = var.enable_cloudfront_invalidation ? 1 : 0
  name        = "${var.project_name}-github-cloudfront-${var.environment}"
  description = "Allow GitHub Actions to invalidate CloudFront cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations",
          "cloudfront:GetDistribution"
        ]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudfront_invalidation" {
  count      = var.enable_cloudfront_invalidation ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cloudfront_invalidation[0].arn
}

# IAM Policy for Migration Lambda Invocation
resource "aws_iam_policy" "migration_lambda" {
  count       = var.enable_migration_lambda ? 1 : 0
  name        = "${var.project_name}-github-migration-lambda-${var.environment}"
  description = "Allow GitHub Actions to invoke migration Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-migrate-${var.environment}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-migrate-${var.environment}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "migration_lambda" {
  count      = var.enable_migration_lambda ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.migration_lambda[0].arn
}

# IAM Policy for ECR Push (Docker images)
resource "aws_iam_policy" "ecr_push" {
  count       = var.enable_ecr_push ? 1 : 0
  name        = "${var.project_name}-github-ecr-push-${var.environment}"
  description = "Allow GitHub Actions to push Docker images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  count      = var.enable_ecr_push ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push[0].arn
}

# IAM Policy for Terraform State Read Access
resource "aws_iam_policy" "terraform_state_read" {
  count       = var.enable_terraform_state_read ? 1 : 0
  name        = "${var.project_name}-github-terraform-state-read-${var.environment}"
  description = "Allow GitHub Actions to read Terraform state for deployment info"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project_name}-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-terraform-locks-${var.environment}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_state_read" {
  count      = var.enable_terraform_state_read ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_state_read[0].arn
}
