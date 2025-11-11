#!/bin/bash

# Deploy Frontend Script
# This script builds the Flutter web app and deploys it to S3/CloudFront

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Frontend Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get the project root directory (3 levels up from tools/sh/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/infra"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Step 1: Get configuration from Terraform
echo -e "${YELLOW}Step 1: Getting deployment configuration...${NC}"
cd "$TERRAFORM_DIR"

S3_BUCKET=$(terraform output -raw frontend_s3_bucket)
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)

if [ -z "$S3_BUCKET" ] || [ -z "$CLOUDFRONT_ID" ] || [ -z "$API_GATEWAY_URL" ]; then
    echo "Error: Failed to get Terraform outputs"
    exit 1
fi

echo "S3 Bucket: $S3_BUCKET"
echo "CloudFront Distribution: $CLOUDFRONT_ID"
echo "API Gateway URL: $API_GATEWAY_URL"
echo -e "${GREEN}✓ Configuration retrieved${NC}"
echo ""

# Step 2: Build Flutter Web App with API configuration
echo -e "${YELLOW}Step 2: Building Flutter web application with production API configuration...${NC}"
cd "$FRONTEND_DIR"
flutter build web --release --dart-define=API_BASE_URL="$API_GATEWAY_URL"

if [ $? -ne 0 ]; then
    echo "Error: Flutter build failed"
    exit 1
fi
echo -e "${GREEN}✓ Flutter build completed with API_BASE_URL=$API_GATEWAY_URL${NC}"
echo ""

# Step 3: Upload files to S3
echo -e "${YELLOW}Step 3: Uploading files to S3...${NC}"
aws s3 sync "$FRONTEND_DIR/build/web/" "s3://$S3_BUCKET/" --delete

if [ $? -ne 0 ]; then
    echo "Error: S3 upload failed"
    exit 1
fi
echo -e "${GREEN}✓ Files uploaded to S3${NC}"
echo ""

# Step 4: Invalidate CloudFront cache
echo -e "${YELLOW}Step 4: Invalidating CloudFront cache...${NC}"
INVALIDATION_OUTPUT=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_ID" --paths "/*")

if [ $? -ne 0 ]; then
    echo "Error: CloudFront invalidation failed"
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
echo -e "Your application is deployed at:"
echo -e "${BLUE}$CLOUDFRONT_URL${NC}"
echo ""
echo -e "${YELLOW}Note: CloudFront invalidation may take a few minutes to complete.${NC}"
echo ""
