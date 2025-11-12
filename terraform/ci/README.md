# CI/CD Infrastructure - GitHub Actions IAM Role

This Terraform stack creates an IAM role for GitHub Actions to deploy the delivery app using OpenID Connect (OIDC) authentication.

## Features

- **OIDC Authentication**: No long-lived AWS credentials needed in GitHub Secrets
- **Fine-grained Permissions**: Modular policies for different deployment tasks
- **Branch Restrictions**: Only specified branches can deploy
- **Security Best Practices**: Short-lived credentials, least privilege access

## Permissions Enabled

The GitHub Actions role can be configured with the following permissions:

1. **Lambda Deployment** - Update Lambda function code and configuration
2. **S3 Deployment** - Deploy frontend to S3 bucket
3. **CloudFront Invalidation** - Clear CDN cache after frontend deployment
4. **Migration Lambda Invocation** - Run database migrations
5. **ECR Push** - Push Docker images (optional, for future containerization)
6. **Terraform State Read** - Read infrastructure state for deployment info

## Prerequisites

1. AWS CLI configured with admin access
2. Terraform >= 1.0
3. A GitHub repository for the delivery app
4. GitHub organization or username

## Setup

### 1. Create tfvars file

```bash
cd terraform/ci
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your GitHub organization/username:

```hcl
github_org = "your-github-username"  # REQUIRED
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Apply the configuration

```bash
terraform apply
```

The output will show instructions for configuring GitHub Actions.

### 5. Configure GitHub Secrets

Go to your repository: `Settings → Secrets and variables → Actions → New repository secret`

Add these secrets:

- `AWS_REGION`: `us-east-1` (or your region)
- `AWS_ROLE_ARN`: Copy from Terraform output `github_actions_role_arn`

## GitHub Actions Workflow Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main, develop]
  workflow_dispatch:

permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required for checkout

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
          role-session-name: GitHubActions-${{ github.run_id }}

      - name: Verify AWS Identity
        run: aws sts get-caller-identity

      - name: Deploy Backend Lambda
        run: |
          cd backend
          ./build-lambda.sh
          aws lambda update-function-code \
            --function-name delivery-app-backend-dev \
            --zip-file fileb://build/lambda.zip

      - name: Deploy Frontend
        run: |
          cd frontend
          flutter build web --release
          aws s3 sync build/web/ s3://delivery-app-frontend-dev-084374024444/ --delete

      - name: Invalidate CloudFront Cache
        run: |
          DISTRIBUTION_ID=$(terraform -chdir=terraform/infra output -raw cloudfront_distribution_id)
          aws cloudfront create-invalidation \
            --distribution-id $DISTRIBUTION_ID \
            --paths "/*"

      - name: Run Database Migration
        run: |
          aws lambda invoke \
            --function-name delivery-app-migrate-dev \
            --payload '{"action":"migrate"}' \
            /tmp/migrate-response.json
          cat /tmp/migrate-response.json
```

## Workflow Examples by Use Case

### Backend Only Deployment

```yaml
- name: Deploy Backend
  run: |
    cd backend/cmd/lambda
    ./build.sh
    aws lambda update-function-code \
      --function-name delivery-app-backend-dev \
      --zip-file fileb://../../build/lambda.zip
```

### Frontend Only Deployment

```yaml
- name: Deploy Frontend
  run: |
    cd frontend
    flutter build web --release --dart-define=API_BASE_URL=${{ secrets.API_URL }}
    aws s3 sync build/web/ s3://delivery-app-frontend-dev-084374024444/ \
      --delete \
      --cache-control "public,max-age=31536000,immutable"

    # Invalidate CloudFront
    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
      --paths "/*"
```

### Database Migration

```yaml
- name: Run Migration
  run: |
    aws lambda invoke \
      --function-name delivery-app-migrate-dev \
      --payload '{"action":"migrate"}' \
      --log-type Tail \
      /tmp/response.json

    # Check response
    cat /tmp/response.json
    if grep -q '"success":false' /tmp/response.json; then
      echo "Migration failed"
      exit 1
    fi
```

## Security Considerations

### 1. Branch Protection

Only specified branches can assume the IAM role. By default:
- `main` - Production deployments
- `develop` - Development deployments

To add more branches, update `terraform.tfvars`:

```hcl
github_branches = ["main", "develop", "staging"]
```

### 2. Repository Restriction

The role can ONLY be assumed from your specific GitHub repository:
- Format: `{github_org}/{github_repo}`
- Cannot be assumed from forks or other repos

### 3. Permission Scoping

Each permission can be individually enabled/disabled:

```hcl
enable_lambda_deployment        = true   # Backend deployment
enable_s3_deployment           = true   # Frontend deployment
enable_cloudfront_invalidation = true   # CDN cache clearing
enable_migration_lambda        = true   # Database migrations
enable_ecr_push                = false  # Docker image push (disabled by default)
enable_terraform_state_read    = true   # Read infrastructure state
```

### 4. Credential Lifetime

OIDC tokens are short-lived (15 minutes by default). No long-lived credentials are stored in GitHub.

## Troubleshooting

### Error: "User is not authorized to perform: sts:AssumeRoleWithWebIdentity"

**Cause**: Branch name doesn't match allowed branches, or repository doesn't match.

**Solution**:
1. Verify branch name in workflow matches `github_branches` in tfvars
2. Verify repository name matches `{github_org}/{github_repo}`
3. Check Terraform outputs: `terraform output allowed_repositories`

### Error: "The security token included in the request is invalid"

**Cause**: OIDC provider thumbprints are outdated or wrong.

**Solution**: GitHub's OIDC thumbprints rarely change. If needed, update in `github_oidc.tf`:

```bash
# Get current thumbprint
openssl s_client -servername token.actions.githubusercontent.com \
  -showcerts -connect token.actions.githubusercontent.com:443 2>&1 < /dev/null \
  | sed -n '/BEGIN/,/END/p' \
  | openssl x509 -noout -fingerprint -sha1 \
  | sed 's/://g' | awk -F= '{print tolower($2)}'
```

### Error: "Access Denied" when deploying Lambda

**Cause**: `enable_lambda_deployment` is false or function name doesn't match pattern.

**Solution**:
1. Set `enable_lambda_deployment = true` in tfvars
2. Verify Lambda function name matches: `{project_name}-*-{environment}`
3. Run `terraform apply` to update permissions

### Workflow doesn't authenticate

**Check**:
1. `permissions.id-token: write` is set in workflow
2. `AWS_ROLE_ARN` secret is correctly set
3. Role ARN matches Terraform output: `terraform output github_actions_role_arn`

## Updating Permissions

To add or remove permissions:

1. Edit `terraform.tfvars`:
```hcl
enable_lambda_deployment = false  # Disable Lambda deployment
```

2. Apply changes:
```bash
terraform apply
```

3. GitHub Actions will automatically use new permissions on next run

## Removing the Stack

```bash
terraform destroy
```

**WARNING**: This will remove the IAM role and OIDC provider. GitHub Actions will no longer be able to deploy.

## Advanced Configuration

### Multiple Environments

Create separate tfvars files:

```bash
# Development
terraform apply -var-file=dev.tfvars

# Production
terraform apply -var-file=prod.tfvars
```

### Custom Role Name

Override the role name:

```hcl
variable "role_name_override" {
  default = "my-custom-role-name"
}
```

### Additional Policies

Attach additional policies in `github_oidc.tf`:

```hcl
resource "aws_iam_role_policy_attachment" "custom" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/CustomPolicy"
}
```

## Resources

- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Configure AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)

## Support

For issues:
1. Check Terraform outputs: `terraform output`
2. Verify GitHub secrets are set correctly
3. Check CloudWatch Logs for Lambda errors
4. Review IAM role trust policy: `aws iam get-role --role-name delivery-app-github-actions-dev`
