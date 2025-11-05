#!/bin/bash

# Distance API Test Script
# Tests the distance calculation endpoint with various scenarios

set -e

# Configuration
BASE_URL="http://localhost:8080"
API_URL="${BASE_URL}/api"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Distance API Test Suite${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to print test result
print_result() {
    local test_name=$1
    local status=$2
    local message=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to make API request
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4

    if [ -n "$token" ]; then
        if [ -n "$data" ]; then
            curl -s -X "$method" "${API_URL}${endpoint}" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            curl -s -X "$method" "${API_URL}${endpoint}" \
                -H "Authorization: Bearer $token"
        fi
    else
        if [ -n "$data" ]; then
            curl -s -X "$method" "${API_URL}${endpoint}" \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            curl -s -X "$method" "${API_URL}${endpoint}"
        fi
    fi
}

# Step 1: Login as customer
echo -e "${YELLOW}Step 1: Authenticating as customer1...${NC}"
LOGIN_RESPONSE=$(api_request POST "/login" '{
    "username": "customer1",
    "password": "password123"
}')

CUSTOMER_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [ -n "$CUSTOMER_TOKEN" ]; then
    echo -e "${GREEN}✓ Customer authentication successful${NC}"
    echo "Token: ${CUSTOMER_TOKEN:0:20}..."
else
    echo -e "${RED}✗ Failed to authenticate as customer${NC}"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi
echo ""

# Step 2: Get customer addresses
echo -e "${YELLOW}Step 2: Fetching customer addresses...${NC}"
ADDRESSES_RESPONSE=$(api_request GET "/addresses" "" "$CUSTOMER_TOKEN")
echo "$ADDRESSES_RESPONSE" | grep -q '"success":true'
if [ $? -eq 0 ]; then
    ADDRESS_ID=$(echo "$ADDRESSES_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    echo -e "${GREEN}✓ Found address ID: $ADDRESS_ID${NC}"
else
    echo -e "${RED}✗ Failed to fetch addresses${NC}"
    echo "Response: $ADDRESSES_RESPONSE"
fi
echo ""

# Step 3: Get restaurants
echo -e "${YELLOW}Step 3: Fetching restaurants...${NC}"
RESTAURANTS_RESPONSE=$(api_request GET "/restaurants" "" "$CUSTOMER_TOKEN")
echo "$RESTAURANTS_RESPONSE" | grep -q '"success":true'
if [ $? -eq 0 ]; then
    RESTAURANT_ID=$(echo "$RESTAURANTS_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    echo -e "${GREEN}✓ Found restaurant ID: $RESTAURANT_ID${NC}"
else
    echo -e "${RED}✗ Failed to fetch restaurants${NC}"
    echo "Response: $RESTAURANTS_RESPONSE"
fi
echo ""

# Run Tests
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Running Distance API Tests${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Test 1: Valid distance calculation
echo -e "${YELLOW}Test 1: Calculate distance with valid IDs${NC}"
if [ -n "$ADDRESS_ID" ] && [ -n "$RESTAURANT_ID" ]; then
    DISTANCE_RESPONSE=$(api_request POST "/distance/estimate" "{
        \"address_id\": $ADDRESS_ID,
        \"restaurant_id\": $RESTAURANT_ID
    }" "$CUSTOMER_TOKEN")

    if echo "$DISTANCE_RESPONSE" | grep -q '"success":true'; then
        DISTANCE_METERS=$(echo "$DISTANCE_RESPONSE" | grep -o '"meters":[0-9]*' | sed 's/"meters"://')
        DURATION_MINUTES=$(echo "$DISTANCE_RESPONSE" | grep -o '"minutes":[0-9]*' | sed 's/"minutes"://')
        print_result "Valid distance calculation" "PASS"
        echo "  Distance: $DISTANCE_METERS meters"
        echo "  Duration: $DURATION_MINUTES minutes"
    else
        print_result "Valid distance calculation" "FAIL" "API returned error: $DISTANCE_RESPONSE"
    fi
else
    print_result "Valid distance calculation" "FAIL" "Missing address_id or restaurant_id"
fi
echo ""

# Test 2: Invalid address ID
echo -e "${YELLOW}Test 2: Invalid address ID (should return 404)${NC}"
INVALID_ADDRESS_RESPONSE=$(api_request POST "/distance/estimate" '{
    "address_id": 99999,
    "restaurant_id": 1
}' "$CUSTOMER_TOKEN")

if echo "$INVALID_ADDRESS_RESPONSE" | grep -q '"success":false'; then
    print_result "Invalid address ID" "PASS"
else
    print_result "Invalid address ID" "FAIL" "Should return error"
fi
echo ""

# Test 3: Invalid restaurant ID
echo -e "${YELLOW}Test 3: Invalid restaurant ID (should return 404)${NC}"
INVALID_RESTAURANT_RESPONSE=$(api_request POST "/distance/estimate" "{
    \"address_id\": $ADDRESS_ID,
    \"restaurant_id\": 99999
}" "$CUSTOMER_TOKEN")

if echo "$INVALID_RESTAURANT_RESPONSE" | grep -q '"success":false'; then
    print_result "Invalid restaurant ID" "PASS"
else
    print_result "Invalid restaurant ID" "FAIL" "Should return error"
fi
echo ""

# Test 4: Missing authentication
echo -e "${YELLOW}Test 4: Missing authentication (should return 401)${NC}"
NO_AUTH_RESPONSE=$(api_request POST "/distance/estimate" "{
    \"address_id\": $ADDRESS_ID,
    \"restaurant_id\": $RESTAURANT_ID
}" "")

if echo "$NO_AUTH_RESPONSE" | grep -q '"success":false'; then
    print_result "Missing authentication" "PASS"
else
    print_result "Missing authentication" "FAIL" "Should return 401"
fi
echo ""

# Test 5: Invalid request body
echo -e "${YELLOW}Test 5: Invalid request body (should return 400)${NC}"
INVALID_BODY_RESPONSE=$(api_request POST "/distance/estimate" '{
    "address_id": -1,
    "restaurant_id": 0
}' "$CUSTOMER_TOKEN")

if echo "$INVALID_BODY_RESPONSE" | grep -q '"success":false'; then
    print_result "Invalid request body" "PASS"
else
    print_result "Invalid request body" "FAIL" "Should return 400"
fi
echo ""

# Test 6: Get distance history
echo -e "${YELLOW}Test 6: Get distance history${NC}"
HISTORY_RESPONSE=$(api_request GET "/distance/history?per_page=10" "" "$CUSTOMER_TOKEN")

if echo "$HISTORY_RESPONSE" | grep -q '"success":true'; then
    print_result "Get distance history" "PASS"
    echo "  History retrieved successfully"
else
    print_result "Get distance history" "FAIL" "API returned error"
fi
echo ""

# Test 7: Admin API usage endpoint
echo -e "${YELLOW}Test 7: Admin API usage endpoint (requires admin token)${NC}"
# Login as admin
ADMIN_LOGIN_RESPONSE=$(api_request POST "/login" '{
    "username": "admin1",
    "password": "password123"
}')

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [ -n "$ADMIN_TOKEN" ]; then
    USAGE_RESPONSE=$(api_request GET "/admin/distance/usage" "" "$ADMIN_TOKEN")

    if echo "$USAGE_RESPONSE" | grep -q '"success":true'; then
        print_result "Admin API usage endpoint" "PASS"
        MONTHLY_COUNT=$(echo "$USAGE_RESPONSE" | grep -o '"count":[0-9]*' | head -1 | sed 's/"count"://')
        echo "  Monthly API usage: $MONTHLY_COUNT requests"
    else
        print_result "Admin API usage endpoint" "FAIL" "API returned error"
    fi
else
    print_result "Admin API usage endpoint" "FAIL" "Failed to authenticate as admin"
fi
echo ""

# Test 8: Customer cannot access admin endpoint
echo -e "${YELLOW}Test 8: Customer cannot access admin endpoint (should return 403)${NC}"
FORBIDDEN_RESPONSE=$(api_request GET "/admin/distance/usage" "" "$CUSTOMER_TOKEN")

if echo "$FORBIDDEN_RESPONSE" | grep -q '"success":false'; then
    print_result "Customer forbidden from admin endpoint" "PASS"
else
    print_result "Customer forbidden from admin endpoint" "FAIL" "Should return 403"
fi
echo ""

# Print summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
