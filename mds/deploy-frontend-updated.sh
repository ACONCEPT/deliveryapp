#!/bin/bash

# Deploy Frontend Script (Updated for Environment Configuration)
# This script builds the Flutter web app and deploys it to S3/CloudFront
#
# Usage:
#   ./deploy-frontend.sh              # Deploy to production
#   ./deploy-frontend.sh --env staging # Deploy to staging

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Frontend Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse command-line arguments
ENVIRONMENT="prod"
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --env ENV       Environment to deploy to (default: prod)"
      echo "  --help          Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Deploy to production"
      echo "  $0 --env staging      # Deploy to staging"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo ""

# Get the project root directory (3 levels up from tools/sh/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/infra"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Step 1: Get deployment configuration from Terraform
echo -e "${YELLOW}Step 1: Getting deployment configuration...${NC}"
cd "$TERRAFORM_DIR"

# Get infrastructure outputs
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw frontend_s3_bucket 2>/dev/null || echo "")
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")

# Validate outputs
if [ -z "$API_GATEWAY_URL" ] || [ -z "$S3_BUCKET" ] || [ -z "$CLOUDFRONT_ID" ]; then
    echo -e "${RED}Error: Failed to get Terraform outputs${NC}"
    echo "Please ensure Terraform infrastructure is deployed."
    echo ""
    echo "Run: cd terraform/infra && terraform apply"
    exit 1
fi

echo "API Gateway URL: $API_GATEWAY_URL"
echo "S3 Bucket: $S3_BUCKET"
echo "CloudFront Distribution: $CLOUDFRONT_ID"
echo -e "${GREEN}✓ Configuration retrieved${NC}"
echo ""

# Step 2: Build Flutter Web App with environment-specific configuration
echo -e "${YELLOW}Step 2: Building Flutter web application...${NC}"
echo "Backend API URL: $API_GATEWAY_URL"
cd "$FRONTEND_DIR"

# Build with environment configuration
flutter build web --release \
  --dart-define=API_BASE_URL="$API_GATEWAY_URL" \
  --dart-define=ENVIRONMENT="$ENVIRONMENT"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Flutter build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter build completed${NC}"
echo ""

# Step 3: Upload files to S3
echo -e "${YELLOW}Step 3: Uploading files to S3...${NC}"
aws s3 sync "$FRONTEND_DIR/build/web/" "s3://$S3_BUCKET/" --delete

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: S3 upload failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Files uploaded to S3${NC}"
echo ""

# Step 4: Invalidate CloudFront cache
echo -e "${YELLOW}Step 4: Invalidating CloudFront cache...${NC}"
INVALIDATION_OUTPUT=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_ID" --paths "/*")

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: CloudFront invalidation failed${NC}"
    exit 1
fi

INVALIDATION_ID=$(echo "$INVALIDATION_OUTPUT" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
echo "Invalidation ID: $INVALIDATION_ID"
echo -e "${GREEN}✓ CloudFront invalidation created${NC}"
echo ""

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration:"
echo -e "  Environment:     ${BLUE}$ENVIRONMENT${NC}"
echo -e "  Backend API:     ${BLUE}$API_GATEWAY_URL${NC}"
echo -e "  Frontend URL:    ${BLUE}$CLOUDFRONT_URL${NC}"
echo ""
echo -e "${YELLOW}Note: CloudFront invalidation may take a few minutes to complete.${NC}"
echo ""
