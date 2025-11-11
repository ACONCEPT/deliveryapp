# Lambda Deployment Guide

This document describes how to build and deploy the delivery app backend to AWS Lambda.

## Architecture

The application is deployed as:
1. **Main Backend API Lambda** - Your Go HTTP server running on Lambda via AWS Lambda Go API Proxy
2. **Scheduled Job Lambdas** - 4 separate Lambda functions for background jobs:
   - Cancel Unconfirmed Orders (every minute)
   - Cleanup Orphaned Menus (daily at 2 AM)
   - Archive Old Orders (weekly on Sunday at 3 AM)
   - Update Driver Availability (every 5 minutes)

## Building Lambda Packages

Run the build script from the project root:

```bash
./build-lambda.sh
```

This will:
- Install AWS Lambda Go dependencies
- Build all Lambda functions for Linux/AMD64
- Create deployment packages in `./build/`:
  - `lambda-deployment.zip` (3.7MB) - Main API
  - `lambda-jobs-deployment.zip` (14MB) - All scheduled jobs

Build artifacts are `.gitignore`d and should not be committed.

## Deploying with Terraform

### Prerequisites
- AWS credentials configured (`aws configure` or environment variables)
- Terraform installed (v1.13.5+)
- Lambda deployment packages built (see above)

### Initial Setup

1. Navigate to the infra directory:
```bash
cd terraform/infra
```

2. Review and update `terraform.tfvars` with your configuration:
   - `jwt_secret` - At least 32 characters (already set)
   - `db_password` - Leave empty to auto-generate
   - `mapbox_access_token` - Optional, for distance calculations

### Deploy

1. Initialize Terraform (first time only):
```bash
# Use the init script (handles macOS temp directory permissions)
./init.sh

# OR manually:
export TMPDIR=~/tmp
terraform init
```

2. Preview changes:
```bash
terraform plan
```

3. Apply infrastructure:
```bash
terraform apply
```

4. When prompted, review the plan and type `yes` to confirm.

### Outputs

After successful deployment, Terraform will output:
- `api_gateway_url` - Your backend API endpoint
- `cloudfront_url` - Your frontend CloudFront distribution URL
- `database_url` - RDS connection string (sensitive)
- `scheduled_jobs_info` - Details about the scheduled jobs

## Updating Lambda Code

When you make changes to the backend code:

1. Rebuild Lambda packages:
```bash
./build-lambda.sh
```

2. Deploy updated code:
```bash
cd terraform/infra
terraform apply
```

Terraform will detect the changed zip files and update the Lambda functions.

## Lambda Configuration

### Main Backend Lambda
- **Runtime**: Custom (Go binary)
- **Memory**: 512 MB (configurable in `terraform.tfvars`)
- **Timeout**: 30 seconds (configurable)
- **VPC**: Deployed in private subnets with access to RDS
- **Environment Variables**:
  - `DATABASE_URL` - From RDS
  - `JWT_SECRET` - From tfvars
  - `TOKEN_DURATION` - From tfvars
  - `SERVER_PORT` - 8080

### Scheduled Job Lambdas
Each job Lambda:
- **Runtime**: Custom (Go binary)
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **VPC**: Deployed in private subnets with access to RDS
- **Trigger**: EventBridge (CloudWatch Events) rules

## Architecture Notes

### Why Lambda?
- **Cost**: Pay only for execution time (Free Tier: 1M requests/month)
- **Scaling**: Automatic scaling with no management
- **Integration**: Native integration with API Gateway, EventBridge, S3
- **Simplicity**: No server management or OS patching

### Handler Implementation
- **Main API**: Uses `awslabs/aws-lambda-go-api-proxy/httpadapter` to wrap the existing Gorilla Mux HTTP server
- **Scheduled Jobs**: Direct Lambda handlers that call job functions from `backend/jobs/`

### Cold Starts
- Initial requests may take 1-2 seconds (cold start)
- Subsequent requests are fast (<100ms)
- Consider provisioned concurrency for production if cold starts are an issue

## Troubleshooting

### Build Issues

**Issue**: `command not found: go`
```bash
# Install Go
brew install go
```

**Issue**: Import errors during build
```bash
cd backend
go mod tidy
go mod download
```

### Deployment Issues

**Issue**: `Failed to load plugin schemas` or `permission denied` on temp files
```bash
# Clean and reinitialize Terraform with custom temp directory
cd terraform/infra
rm -rf .terraform .terraform.lock.hcl
./init.sh
```

**Issue**: `Error acquiring the state lock`
```bash
# Force unlock (use the lock ID from the error message)
terraform force-unlock <LOCK_ID>
```

**Issue**: `lambda_deployment_package: no such file`
```bash
# Build the Lambda packages first
./build-lambda.sh
```

### Runtime Issues

**Issue**: Lambda function timing out
- Check CloudWatch Logs for the specific Lambda function
- Increase `lambda_timeout` in `terraform.tfvars`
- Check VPC security groups allow Lambda to reach RDS

**Issue**: Database connection errors
- Verify RDS is running: Check AWS Console
- Check Lambda security group can reach RDS security group
- Verify `DATABASE_URL` environment variable is set correctly

## Monitoring

### CloudWatch Logs
Each Lambda function logs to CloudWatch Logs:
- Main API: `/aws/lambda/delivery-app-backend-dev`
- Jobs: `/aws/lambda/delivery-app-job-*-dev`

Retention: 7 days (configurable in `terraform.tfvars`)

### API Gateway Logs
API Gateway access logs: `/aws/apigateway/delivery-app-dev`

### Metrics
CloudWatch Metrics automatically tracked:
- Lambda invocations
- Lambda errors
- Lambda duration
- API Gateway requests
- API Gateway latency

## Cost Estimates (Free Tier)

- **Lambda**: 1M requests/month + 400,000 GB-seconds free
- **API Gateway**: 1M API calls/month free (first 12 months)
- **RDS**: db.t3.micro 750 hours/month free (first 12 months)
- **CloudFront**: 1 TB data transfer/month free (first 12 months)
- **S3**: 5 GB storage + 20,000 GET + 2,000 PUT free

**Estimated monthly cost after Free Tier**: $15-30 for low traffic

## Related Files

- `./build-lambda.sh` - Build script for Lambda packages
- `backend/cmd/lambda/main.go` - Main API Lambda handler
- `backend/cmd/lambda-jobs/*/main.go` - Scheduled job Lambda handlers
- `backend/middleware/common.go` - Shared middleware for Lambda
- `terraform/infra/lambda.tf` - Lambda infrastructure configuration
- `terraform/infra/scheduled_jobs.tf` - EventBridge rules for jobs
- `terraform/infra/variables.tf` - Terraform variable definitions
- `terraform/infra/terraform.tfvars` - Your variable values

## Next Steps

1. Build Lambda packages: `./build-lambda.sh`
2. Deploy infrastructure: `cd terraform/infra && terraform apply`
3. Test API endpoint: Use the `api_gateway_url` output
4. Deploy frontend: Upload Flutter build to S3 (separate process)
5. Set up custom domain (optional): Configure Route53 + ACM

For production deployment, consider:
- [ ] Set `enable_deletion_protection = true`
- [ ] Set `skip_final_snapshot = false`
- [ ] Enable CloudFront logging
- [ ] Set up custom domains with ACM certificates
- [ ] Configure CloudWatch alarms
- [ ] Set up backup strategy for RDS
- [ ] Review and tighten security groups
- [ ] Enable AWS WAF for API Gateway
