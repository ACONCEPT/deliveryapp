# GitHub OIDC Provider
# This allows GitHub Actions to authenticate with AWS without long-lived credentials
# Reference: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's OIDC thumbprints (updated as of 2023)
  # Primary thumbprint from GitHub's current certificate chain
  thumbprint_list = [
    "1b511abead59c6ce207077c0bf0e0043b1382612",  # Current GitHub Actions OIDC thumbprint
    "6938fd4d98bab03faadb97b34396831e3780aea1"   # Legacy thumbprint for backwards compatibility
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
            # Allow assuming role from specific repo, branches, and environments
            "token.actions.githubusercontent.com:sub" = concat(
              [
                for branch in var.github_branches :
                "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"
              ],
              [
                # Allow GitHub environments
                "repo:${var.github_org}/${var.github_repo}:environment:*"
              ]
            )
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

# IAM Policy for Terraform State Management
resource "aws_iam_policy" "terraform_state_read" {
  count       = var.enable_terraform_state_read ? 1 : 0
  name        = "${var.project_name}-github-terraform-state-read-${var.environment}"
  description = "Allow GitHub Actions to manage Terraform state and locking"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
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
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
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

# IAM Policy for Terraform Infrastructure Management
resource "aws_iam_policy" "terraform_infrastructure" {
  count       = var.enable_terraform_infrastructure ? 1 : 0
  name        = "${var.project_name}-github-terraform-infra-${var.environment}"
  description = "Allow GitHub Actions to manage infrastructure via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:ListTags",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:DeleteAlias",
          "lambda:GetAlias",
          "lambda:UpdateAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*-${var.environment}"
        ]
      },
      # IAM Role permissions for Lambda execution roles
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*-${var.environment}"
        ]
      },
      # IAM Policy permissions
      {
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-*-${var.environment}"
        ]
      },
      # API Gateway permissions
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*"
        ]
      },
      # S3 permissions for frontend and other buckets
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketCORS",
          "s3:PutBucketCORS",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-${var.environment}-${data.aws_caller_identity.current.account_id}"
        ]
      },
      # CloudFront permissions
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl"
        ]
        Resource = "*"
      },
      # RDS permissions
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups",
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:DeleteDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${var.project_name}-*-${var.environment}",
          "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subgrp:${var.project_name}-*-${var.environment}"
        ]
      },
      # VPC permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:AssociateRouteTable",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:AllocateAddress",
          "ec2:CreateNatGateway",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifySubnetAttribute",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:DisassociateRouteTable",
          "ec2:DeleteInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:ReleaseAddress",
          "ec2:DeleteNatGateway"
        ]
        Resource = "*"
      },
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsLogGroup"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*-${var.environment}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*-${var.environment}:*"
        ]
      },
      # Secrets Manager permissions
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:PutSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:PutResourcePolicy"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_infrastructure" {
  count      = var.enable_terraform_infrastructure ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_infrastructure[0].arn
}
