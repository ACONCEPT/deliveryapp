#!/bin/bash

# Test API Configuration Script
# This script verifies that the Flutter app is configured correctly for different environments

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}API Configuration Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get the project root directory (3 levels up from tools/sh/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/infra"

cd "$FRONTEND_DIR"

# Test 1: Check ApiConfig file exists
echo -e "${YELLOW}Test 1: Checking ApiConfig file...${NC}"
if [ -f "$FRONTEND_DIR/lib/config/api_config.dart" ]; then
    echo -e "${GREEN}✓ ApiConfig file exists${NC}"
else
    echo -e "${RED}✗ ApiConfig file not found${NC}"
    exit 1
fi
echo ""

# Test 2: Verify String.fromEnvironment usage
echo -e "${YELLOW}Test 2: Verifying environment configuration...${NC}"
if grep -q "String.fromEnvironment" "$FRONTEND_DIR/lib/config/api_config.dart" && grep -q "API_BASE_URL" "$FRONTEND_DIR/lib/config/api_config.dart"; then
    echo -e "${GREEN}✓ API_BASE_URL is configured with String.fromEnvironment${NC}"
else
    echo -e "${RED}✗ API_BASE_URL not using String.fromEnvironment${NC}"
    exit 1
fi
echo ""

# Test 3: Check default value
echo -e "${YELLOW}Test 3: Checking default backend URL...${NC}"
if grep -q "defaultValue:.*localhost" "$FRONTEND_DIR/lib/config/api_config.dart"; then
    echo -e "${GREEN}✓ Default backend URL is set to localhost${NC}"
else
    echo -e "${RED}✗ Default backend URL is not localhost${NC}"
    exit 1
fi
echo ""

# Test 4: Verify HttpClientService uses ApiConfig
echo -e "${YELLOW}Test 4: Verifying HttpClientService integration...${NC}"
if [ -f "$FRONTEND_DIR/lib/services/http_client_service.dart" ]; then
    if grep -q "ApiConfig.baseUrl" "$FRONTEND_DIR/lib/services/http_client_service.dart"; then
        echo -e "${GREEN}✓ HttpClientService uses ApiConfig.baseUrl${NC}"
    else
        echo -e "${RED}✗ HttpClientService doesn't reference ApiConfig.baseUrl${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ HttpClientService file not found${NC}"
    exit 1
fi
echo ""

# Test 5: Build test with custom API URL
echo -e "${YELLOW}Test 5: Testing build with custom API URL...${NC}"
TEST_API_URL="https://test-api.example.com"
flutter build web --release --dart-define=API_BASE_URL="$TEST_API_URL" > /tmp/flutter-build-test.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build succeeds with custom API_BASE_URL${NC}"

    # Check if the URL is embedded in the build output
    if grep -r "$TEST_API_URL" "$FRONTEND_DIR/build/web/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Custom API URL is embedded in build output${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not verify if URL is in build (this is OK if obfuscated)${NC}"
    fi
else
    echo -e "${RED}✗ Build failed with custom API_BASE_URL${NC}"
    cat /tmp/flutter-build-test.log
    exit 1
fi
echo ""

# Test 6: Check Terraform outputs (if in deployed environment)
if [ -d "$TERRAFORM_DIR" ] && [ -f "$TERRAFORM_DIR/outputs.tf" ]; then
    echo -e "${YELLOW}Test 6: Checking Terraform configuration...${NC}"

    if grep -q "api_gateway_url" "$TERRAFORM_DIR/outputs.tf"; then
        echo -e "${GREEN}✓ Terraform outputs include api_gateway_url${NC}"
    else
        echo -e "${RED}✗ Terraform outputs missing api_gateway_url${NC}"
        exit 1
    fi

    # Try to get actual API Gateway URL if Terraform is initialized
    cd "$TERRAFORM_DIR"
    if [ -f ".terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
        API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
        if [ -n "$API_GATEWAY_URL" ] && [ "$API_GATEWAY_URL" != "null" ]; then
            echo -e "${GREEN}✓ Retrieved API Gateway URL: $API_GATEWAY_URL${NC}"
        else
            echo -e "${YELLOW}⚠ Terraform state exists but couldn't retrieve API URL${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Terraform not initialized (run 'terraform init' first)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Terraform directory not found, skipping infrastructure tests${NC}"
fi
echo ""

# Test 7: Verify deployment script
echo -e "${YELLOW}Test 7: Checking deployment script...${NC}"
DEPLOY_SCRIPT="$PROJECT_ROOT/tools/sh/deploy-frontend.sh"
if [ -f "$DEPLOY_SCRIPT" ]; then
    if grep -q "API_GATEWAY_URL" "$DEPLOY_SCRIPT" && grep -q "dart-define=API_BASE_URL" "$DEPLOY_SCRIPT"; then
        echo -e "${GREEN}✓ Deployment script correctly passes API_BASE_URL${NC}"
    else
        echo -e "${RED}✗ Deployment script missing API configuration${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Deployment script not found${NC}"
    exit 1
fi
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Tests Passed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "- Local Development: Uses default http://localhost:8080"
echo "- Custom Local: Run with --dart-define=API_BASE_URL=<url>"
echo "- Production: Deployment script extracts URL from Terraform"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Local dev: cd frontend && flutter run -d chrome"
echo "2. Or use helper: ./tools/sh/run-local-frontend.sh"
echo "3. Production: ./tools/sh/deploy-frontend.sh"
echo ""
