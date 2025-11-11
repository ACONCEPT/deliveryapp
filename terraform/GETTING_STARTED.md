# Getting Started with Terraform Deployment

Quick start guide for deploying the Delivery App to AWS.

## Prerequisites

- ✅ AWS Account
- ✅ AWS CLI installed and configured (`aws configure`)
- ✅ Terraform installed (`brew install hashicorp/tap/terraform`)
- ✅ Go installed (for building Lambda packages)

## Deployment Steps

### 1. Setup Remote Backend (One-time)

```bash
cd terraform
./setup-backend.sh
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- `infra/backend.hcl` configuration file

### 2. Deploy Infrastructure

```bash
cd infra

# Initialize with remote backend
terraform init -backend-config=backend.hcl

# Build Lambda deployment packages
./scripts/build-lambda.sh
./scripts/build-jobs-lambda.sh

# Configure your deployment
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit settings

# Deploy!
terraform plan
terraform apply
```

### 3. Initialize Database

```bash
# Get database connection string
terraform output -raw database_url

# Run migrations
psql "$(terraform output -raw database_url)" -f ../../backend/sql/schema.sql
```

### 4. Deploy Frontend

```bash
cd ../../frontend
flutter build web

cd ../terraform/infra
FRONTEND_BUCKET=$(terraform output -raw frontend_s3_bucket)
aws s3 sync ../../frontend/build/web/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront cache
CF_DIST=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $CF_DIST --paths "/*"
```

### 5. Access Your Application

```bash
terraform output application_urls
```

## Directory Structure

```
terraform/
├── GETTING_STARTED.md  ← You are here
├── README.md           ← Remote backend documentation
├── setup-backend.sh    ← Backend setup script
├── backend/            ← Remote state infrastructure
└── infra/              ← Main application infrastructure
    ├── README.md       ← Detailed infrastructure docs
    └── scripts/        ← Build scripts
```

## Common Commands

```bash
# View all resources
terraform state list

# View outputs
terraform output

# View specific output
terraform output api_gateway_url

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Update infrastructure
terraform plan
terraform apply

# Destroy everything
terraform destroy
```

## Environments

For multiple environments (dev/staging/prod):

```bash
# Create separate backend configs
cp infra/backend.hcl infra/backend-prod.hcl
# Edit backend-prod.hcl with prod bucket/table

# Initialize with different backend
terraform init -backend-config=backend-prod.hcl -reconfigure

# Use workspace or separate tfvars
terraform workspace new prod
# or
terraform apply -var-file=terraform-prod.tfvars
```

## Need Help?

- **Backend Setup**: See [README.md](README.md)
- **Infrastructure Details**: See [infra/README.md](infra/README.md)
- **AWS Issues**: Run `aws sts get-caller-identity` to verify credentials
- **Terraform Issues**: Run `terraform init -upgrade` to update providers

## Quick Troubleshooting

**"Error acquiring state lock"**
```bash
terraform force-unlock LOCK_ID
```

**"Backend does not exist"**
```bash
cd backend && terraform apply
```

**"AWS credentials not configured"**
```bash
aws configure
```

**"Lambda package not found"**
```bash
cd infra
./scripts/build-lambda.sh
./scripts/build-jobs-lambda.sh
```

## What Gets Deployed?

- **VPC** with public/private subnets
- **RDS PostgreSQL** database (db.t3.micro, 20GB)
- **Lambda Functions**:
  - API backend (Go HTTP server)
  - 4 scheduled jobs (maintenance tasks)
- **API Gateway HTTP API** (with Lambda proxy)
- **S3 Buckets**:
  - Frontend hosting
  - Uploads storage
- **CloudFront** distribution (global CDN)
- **EventBridge** rules (scheduled jobs)
- **Secrets Manager** (database credentials)

## Cost Estimate

**Free Tier (12 months)**: $0-5/month
**After Free Tier**: $15-30/month

See [infra/README.md](infra/README.md) for detailed cost breakdown.

---

Ready to deploy? Run `./setup-backend.sh` to get started! 🚀
