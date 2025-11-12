#!/bin/bash

# Run Database Migrations Script
# This script invokes the migration Lambda function to run database migrations

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Database Migration Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/infra"

# Check if environment argument is provided
ENVIRONMENT="${1:-dev}"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo -e "${RED}Error: Invalid environment. Use 'dev' or 'prod'${NC}"
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"
echo ""

# Step 1: Get migration Lambda function name from Terraform
echo -e "${YELLOW}Step 1: Getting migration Lambda function name from Terraform...${NC}"
cd "$TERRAFORM_DIR"

# Use appropriate backend config based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    terraform init -backend-config="backend-prod.hcl" -reconfigure > /dev/null 2>&1
else
    terraform init -backend-config="backend.hcl" -reconfigure > /dev/null 2>&1
fi

FUNCTION_NAME=$(terraform output -raw migrate_lambda_name 2>/dev/null)

if [ -z "$FUNCTION_NAME" ]; then
    echo -e "${RED}Error: Could not retrieve migration Lambda function name from Terraform${NC}"
    echo "Make sure you have deployed the infrastructure with Terraform"
    exit 1
fi

echo "Migration Lambda: $FUNCTION_NAME"
echo -e "${GREEN}✓ Function name retrieved${NC}"
echo ""

# Step 2: Invoke migration Lambda
echo -e "${YELLOW}Step 2: Running database migrations...${NC}"

RESPONSE_FILE="/tmp/migrate-response-$$.json"

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload '{"action":"migrate"}' \
    --region "${AWS_REGION:-us-east-1}" \
    "$RESPONSE_FILE" \
    > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to invoke migration Lambda${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Migration Lambda invoked${NC}"
echo ""

# Step 3: Display results
echo -e "${YELLOW}Step 3: Migration results:${NC}"
echo -e "${BLUE}========================================${NC}"
cat "$RESPONSE_FILE" | python3 -m json.tool 2>/dev/null || cat "$RESPONSE_FILE"
echo -e "${BLUE}========================================${NC}"
echo ""

# Clean up
rm -f "$RESPONSE_FILE"

# Check if migration was successful
if grep -q '"success".*true' "$RESPONSE_FILE" 2>/dev/null || grep -q 'success' "$RESPONSE_FILE" 2>/dev/null; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Migrations Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Migration may have failed - check output above${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
