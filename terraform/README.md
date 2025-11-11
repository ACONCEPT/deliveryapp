# Terraform Infrastructure

This directory contains Terraform configuration for deploying the Delivery App to AWS with remote state management.

## Directory Structure

```
terraform/
├── backend/           # Remote state backend (S3 + DynamoDB)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── infra/            # Main infrastructure (Lambda, RDS, API Gateway, etc.)
│   ├── main.tf
│   ├── rds.tf
│   ├── lambda.tf
│   ├── api_gateway.tf
│   ├── cloudfront.tf
│   ├── scheduled_jobs.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.hcl   # Generated backend config
│   ├── scripts/
│   │   ├── build-lambda.sh
│   │   └── build-jobs-lambda.sh
│   └── README.md     # Detailed infrastructure documentation
└── setup-backend.sh  # Automated backend setup script
```

## Why Remote State?

Remote state backend provides:

✅ **Team Collaboration** - Multiple developers can work on the same infrastructure
✅ **State Locking** - Prevents concurrent modifications (via DynamoDB)
✅ **State History** - S3 versioning keeps historical state versions
✅ **Security** - Encrypted state storage, no local sensitive data
✅ **Backup** - Automatic versioning and point-in-time recovery

## Quick Start

### Step 1: Set Up AWS Credentials

```bash
aws configure
```

### Step 2: Create Remote Backend

Run the automated setup script:

```bash
cd terraform
./setup-backend.sh
```

This creates:
- **S3 Bucket**: Stores Terraform state files
- **DynamoDB Table**: Handles state locking
- **backend.hcl**: Configuration file for infrastructure

The script will:
1. Verify AWS credentials
2. Initialize the backend Terraform
3. Create S3 bucket with versioning and encryption
4. Create DynamoDB table for state locking
5. Generate `infra/backend.hcl` configuration file

### Step 3: Deploy Infrastructure

```bash
cd infra

# Initialize with remote backend
terraform init -backend-config=backend.hcl

# Build Lambda packages
./scripts/build-lambda.sh
./scripts/build-jobs-lambda.sh

# Configure variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your settings

# Deploy
terraform plan
terraform apply
```

## Manual Backend Setup

If you prefer manual setup:

### 1. Create Backend Infrastructure

```bash
cd backend
terraform init
terraform plan
terraform apply
```

### 2. Get Backend Configuration

```bash
terraform output backend_config
```

### 3. Create backend.hcl

Create `infra/backend.hcl` with the output values:

```hcl
bucket         = "delivery-app-terraform-state-dev-123456789012"
key            = "infra/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "delivery-app-terraform-locks-dev"
```

### 4. Initialize Infrastructure with Backend

```bash
cd ../infra
terraform init -backend-config=backend.hcl
```

## Backend Configuration

### Environment Variables

Backend configuration can use environment variables:

```bash
# Set backend bucket
export TF_CLI_ARGS_init="-backend-config=bucket=my-custom-bucket"

# Initialize
terraform init
```

### Multiple Environments

For different environments (dev, staging, prod):

**Option 1: Separate Backend Config Files**

```bash
# backend-dev.hcl
bucket = "delivery-app-terraform-state-dev-123456789012"
key    = "infra/terraform.tfstate"
region = "us-east-1"

# backend-prod.hcl
bucket = "delivery-app-terraform-state-prod-123456789012"
key    = "infra/terraform.tfstate"
region = "us-east-1"

# Use different configs
terraform init -backend-config=backend-dev.hcl
terraform init -backend-config=backend-prod.hcl -reconfigure
```

**Option 2: Different State Keys**

```bash
# Dev
bucket = "delivery-app-terraform-state-123456789012"
key    = "dev/infra/terraform.tfstate"

# Prod
bucket = "delivery-app-terraform-state-123456789012"
key    = "prod/infra/terraform.tfstate"
```

## State Management

### View Current State

```bash
cd infra

# List all resources
terraform state list

# Show specific resource
terraform state show aws_lambda_function.backend

# View entire state
terraform show
```

### State Locking

State locking prevents concurrent modifications:

```bash
# Lock is acquired automatically during:
terraform plan
terraform apply
terraform destroy

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### State Backup and Recovery

S3 versioning provides automatic backups:

```bash
# List state versions
aws s3api list-object-versions \
  --bucket delivery-app-terraform-state-dev-123456789012 \
  --prefix infra/terraform.tfstate

# Recover previous version
aws s3api get-object \
  --bucket delivery-app-terraform-state-dev-123456789012 \
  --key infra/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.backup
```

### Migrating to Remote Backend

If you have existing local state:

```bash
cd infra

# Backup local state
cp terraform.tfstate terraform.tfstate.local.backup

# Initialize with remote backend (automatically migrates state)
terraform init -backend-config=backend.hcl

# Verify migration
terraform state list

# Remote state is now active!
```

## Troubleshooting

### "Error acquiring the state lock"

Another process is running Terraform. Wait for it to complete or force unlock:

```bash
# Find lock info in DynamoDB console or
terraform force-unlock LOCK_ID
```

### "Backend configuration changed"

Reinitialize Terraform:

```bash
terraform init -reconfigure -backend-config=backend.hcl
```

### "Access Denied" to S3/DynamoDB

Ensure your IAM user/role has permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::delivery-app-terraform-state-*",
        "arn:aws:s3:::delivery-app-terraform-state-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/delivery-app-terraform-locks-*"
    }
  ]
}
```

### "Backend does not exist"

Run backend setup first:

```bash
cd ../backend
terraform apply
```

## Best Practices

### ✅ Do

- **Always use remote backend** for team projects
- **Enable versioning** on state bucket (already configured)
- **Encrypt state** at rest (already configured)
- **Use state locking** to prevent conflicts (already configured)
- **Backup state regularly** (S3 versioning handles this)
- **Use separate backends** for different environments
- **Review state changes** with `terraform plan`

### ❌ Don't

- **Never edit state manually** - Use `terraform state` commands
- **Never commit state files** to git (already in .gitignore)
- **Never disable state locking** in production
- **Never share backend** between unrelated projects
- **Don't force-unlock** unless absolutely necessary
- **Don't delete state bucket** without backing up state

## Security

### State Encryption

State is encrypted at rest (AES256) and in transit (HTTPS).

### Access Control

Restrict S3 bucket access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::delivery-app-terraform-state-*",
        "arn:aws:s3:::delivery-app-terraform-state-*/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

### Sensitive Data

State files may contain sensitive data (passwords, keys). The backend ensures:

- ✓ Encryption at rest
- ✓ Encryption in transit
- ✓ No public access
- ✓ Versioning for recovery
- ✓ Access logging (optional)

## Cleanup

To destroy the backend (WARNING: This deletes state storage):

```bash
# First destroy all infrastructure
cd infra
terraform destroy

# Then destroy backend (removes state storage permanently!)
cd ../backend
terraform destroy
```

**Note**: This will delete all Terraform state history. Only do this if you're completely done with the project.

## Cost

Backend resources cost:

- **S3**: ~$0.023/GB/month + $0.005 per 1000 PUT requests
- **DynamoDB**: Pay-per-request (Free Tier: 25 WCU/RCU)

For typical usage: **< $1/month**

State locking is extremely lightweight - usually just a few requests per `terraform apply`.

## Resources

- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Terraform State](https://www.terraform.io/docs/language/state/index.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Backend Configuration](https://www.terraform.io/docs/language/settings/backends/configuration.html)

For infrastructure deployment details, see [infra/README.md](infra/README.md).
