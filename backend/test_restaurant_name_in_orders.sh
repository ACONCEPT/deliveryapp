#!/bin/bash

# Test script to verify restaurant_name is included in all order list endpoints
# This script assumes the backend is running on http://localhost:8080

BASE_URL="http://localhost:8080"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Testing Restaurant Name in Order Lists"
echo "=========================================="
echo ""

# Step 1: Login as customer to get token
echo -e "${YELLOW}Step 1: Logging in as customer...${NC}"
CUSTOMER_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer1",
    "password": "password123"
  }')

CUSTOMER_TOKEN=$(echo "$CUSTOMER_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CUSTOMER_TOKEN" ]; then
  echo -e "${RED}Failed to get customer token${NC}"
  echo "Response: $CUSTOMER_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}Customer token obtained${NC}"
echo ""

# Step 2: Login as vendor to get token
echo -e "${YELLOW}Step 2: Logging in as vendor...${NC}"
VENDOR_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }')

VENDOR_TOKEN=$(echo "$VENDOR_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$VENDOR_TOKEN" ]; then
  echo -e "${RED}Failed to get vendor token${NC}"
  echo "Response: $VENDOR_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}Vendor token obtained${NC}"
echo ""

# Step 3: Login as driver to get token
echo -e "${YELLOW}Step 3: Logging in as driver...${NC}"
DRIVER_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "driver1",
    "password": "password123"
  }')

DRIVER_TOKEN=$(echo "$DRIVER_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$DRIVER_TOKEN" ]; then
  echo -e "${RED}Failed to get driver token${NC}"
  echo "Response: $DRIVER_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}Driver token obtained${NC}"
echo ""

# Step 4: Login as admin to get token
echo -e "${YELLOW}Step 4: Logging in as admin...${NC}"
ADMIN_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo -e "${RED}Failed to get admin token${NC}"
  echo "Response: $ADMIN_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}Admin token obtained${NC}"
echo ""

# Function to check if response contains restaurant_name
check_restaurant_name() {
  local endpoint="$1"
  local token="$2"
  local description="$3"

  echo -e "${YELLOW}Testing: $description${NC}"
  RESPONSE=$(curl -s -X GET "$BASE_URL$endpoint" \
    -H "Authorization: Bearer $token")

  # Check if response contains restaurant_name
  if echo "$RESPONSE" | grep -q "restaurant_name"; then
    echo -e "${GREEN}✓ PASS: restaurant_name found${NC}"
    # Show a sample of the restaurant_name
    echo "$RESPONSE" | grep -o '"restaurant_name":"[^"]*"' | head -1
  else
    echo -e "${RED}✗ FAIL: restaurant_name NOT found${NC}"
    echo "Response: $RESPONSE"
  fi
  echo ""
}

echo "=========================================="
echo "CUSTOMER ENDPOINTS"
echo "=========================================="
check_restaurant_name "/api/customer/orders" "$CUSTOMER_TOKEN" "GET /api/customer/orders (list all customer orders)"
check_restaurant_name "/api/customer/orders/1" "$CUSTOMER_TOKEN" "GET /api/customer/orders/{id} (get single order)"

echo "=========================================="
echo "VENDOR ENDPOINTS"
echo "=========================================="
check_restaurant_name "/api/vendor/orders" "$VENDOR_TOKEN" "GET /api/vendor/orders (list vendor orders)"
check_restaurant_name "/api/vendor/orders/1" "$VENDOR_TOKEN" "GET /api/vendor/orders/{id} (get single order)"

echo "=========================================="
echo "DRIVER ENDPOINTS"
echo "=========================================="
check_restaurant_name "/api/driver/orders" "$DRIVER_TOKEN" "GET /api/driver/orders (list driver assigned orders)"
check_restaurant_name "/api/driver/orders/available" "$DRIVER_TOKEN" "GET /api/driver/orders/available (list available orders)"

echo "=========================================="
echo "ADMIN ENDPOINTS"
echo "=========================================="
check_restaurant_name "/api/admin/orders" "$ADMIN_TOKEN" "GET /api/admin/orders (list all orders)"
check_restaurant_name "/api/admin/orders/1" "$ADMIN_TOKEN" "GET /api/admin/orders/{id} (get single order)"

echo "=========================================="
echo "PERFORMANCE CHECK"
echo "=========================================="
echo -e "${YELLOW}Checking for JOINs in query execution...${NC}"
echo "This would require EXPLAIN ANALYZE on actual database queries."
echo "Manual verification needed:"
echo "  psql -d delivery_app -c \"EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;\""
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="
