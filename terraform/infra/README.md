# Delivery App - Terraform Infrastructure

This directory contains the Terraform configuration for deploying the delivery app to AWS.

## Quick Start

```bash
# 1. Build Lambda packages (from project root)
cd ../..
./build-lambda.sh

# 2. Return to infra directory
cd terraform/infra

# 3. Initialize Terraform (use init.sh to avoid macOS permission issues)
./init.sh

# OR manually with custom temp dir:
# export TMPDIR=~/tmp && terraform init

# 4. Review the plan
terraform plan

# 5. Deploy
terraform apply
```

## macOS Permissions Note

⚠️ macOS may have restricted permissions on `/var/folders/` temp directories. Use `./init.sh` instead of `terraform init` to avoid permission errors.

## Configuration

The S3 backend is hardcoded in `main.tf`:
- **Bucket**: `delivery-app-terraform-state-dev-084374024444`
- **Key**: `infra/terraform.tfstate`
- **Region**: `us-east-1`
- **Lock Table**: `delivery-app-terraform-locks-dev`

No `-backend-config` parameter needed - just run `terraform init`.

## What Gets Deployed

- **VPC**: 10.0.0.0/16 with public/private subnets in 2 AZs
- **RDS**: PostgreSQL db.t3.micro
- **Lambda**: Backend API + 4 scheduled jobs
- **API Gateway**: HTTP API with CORS
- **CloudFront + S3**: Frontend hosting
- **EventBridge**: Scheduled job triggers

**Total**: 68 resources

## Documentation

See `/LAMBDA_DEPLOYMENT.md` for complete documentation.
