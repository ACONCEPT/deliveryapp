#!/bin/bash

# Test script to verify admin access to vendor restaurant settings endpoints
# Tests all authorization scenarios: admin, vendor (owner), vendor (non-owner), customer

set -e

BASE_URL="http://localhost:8080/api"
echo "========================================"
echo "Testing Admin Access to Vendor Routes"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print test results
print_result() {
    local test_name=$1
    local expected_status=$2
    local actual_status=$3

    if [ "$expected_status" -eq "$actual_status" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name (HTTP $actual_status)"
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name (Expected $expected_status, got $actual_status)"
    fi
}

# Step 1: Login as admin
echo "Step 1: Logging in as admin..."
ADMIN_RESPONSE=$(curl -s -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin1", "password": "password123"}')

ADMIN_TOKEN=$(echo $ADMIN_RESPONSE | jq -r '.token // empty')
if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}Failed to get admin token${NC}"
    echo "Response: $ADMIN_RESPONSE"
    exit 1
fi
echo -e "${GREEN}Admin logged in successfully${NC}"
echo ""

# Step 2: Login as vendor (who owns restaurant ID 1)
echo "Step 2: Logging in as vendor1..."
VENDOR_RESPONSE=$(curl -s -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "vendor1", "password": "password123"}')

VENDOR_TOKEN=$(echo $VENDOR_RESPONSE | jq -r '.token // empty')
if [ -z "$VENDOR_TOKEN" ]; then
    echo -e "${RED}Failed to get vendor token${NC}"
    echo "Response: $VENDOR_RESPONSE"
    exit 1
fi
echo -e "${GREEN}Vendor logged in successfully${NC}"
echo ""

# Step 3: Login as customer (should be denied)
echo "Step 3: Logging in as customer1..."
CUSTOMER_RESPONSE=$(curl -s -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "customer1", "password": "password123"}')

CUSTOMER_TOKEN=$(echo $CUSTOMER_RESPONSE | jq -r '.token // empty')
if [ -z "$CUSTOMER_TOKEN" ]; then
    echo -e "${RED}Failed to get customer token${NC}"
    echo "Response: $CUSTOMER_RESPONSE"
    exit 1
fi
echo -e "${GREEN}Customer logged in successfully${NC}"
echo ""

# Test 1: Admin can GET restaurant settings
echo "========================================="
echo "Test 1: Admin GET /api/vendor/restaurant/1/settings"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Admin GET restaurant settings" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 2: Admin can PUT restaurant settings
echo "========================================="
echo "Test 2: Admin PUT /api/vendor/restaurant/1/settings"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 25,
    "hours_of_operation": {
      "monday": {"closed": false, "open": "09:00", "close": "22:00"},
      "tuesday": {"closed": false, "open": "09:00", "close": "22:00"},
      "wednesday": {"closed": false, "open": "09:00", "close": "22:00"},
      "thursday": {"closed": false, "open": "09:00", "close": "22:00"},
      "friday": {"closed": false, "open": "09:00", "close": "23:00"},
      "saturday": {"closed": false, "open": "10:00", "close": "23:00"},
      "sunday": {"closed": false, "open": "10:00", "close": "21:00"}
    }
  }')
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Admin PUT restaurant settings" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 3: Admin can PATCH prep time
echo "========================================="
echo "Test 3: Admin PATCH /api/vendor/restaurant/1/prep-time"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH $BASE_URL/vendor/restaurant/1/prep-time \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"average_prep_time_minutes": 30}')
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Admin PATCH prep time" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 4: Vendor can access their own restaurant settings
echo "========================================="
echo "Test 4: Vendor GET /api/vendor/restaurant/1/settings (owned)"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $VENDOR_TOKEN")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Vendor GET owned restaurant settings" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 5: Vendor cannot access restaurant they don't own
echo "========================================="
echo "Test 5: Vendor GET /api/vendor/restaurant/999/settings (not owned)"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET $BASE_URL/vendor/restaurant/999/settings \
  -H "Authorization: Bearer $VENDOR_TOKEN")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
# Expect either 403 (forbidden) or 404 (not found)
if [ "$STATUS" -eq 403 ] || [ "$STATUS" -eq 404 ]; then
    echo -e "${GREEN}✓ PASS${NC}: Vendor blocked from non-owned restaurant (HTTP $STATUS)"
else
    echo -e "${RED}✗ FAIL${NC}: Expected 403 or 404, got $STATUS"
fi
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 6: Customer cannot access vendor settings
echo "========================================="
echo "Test 6: Customer GET /api/vendor/restaurant/1/settings (denied)"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $CUSTOMER_TOKEN")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Customer denied access to vendor routes" 403 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 7: Admin can access via admin-specific routes
echo "========================================="
echo "Test 7: Admin GET /api/admin/restaurant/1/settings"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET $BASE_URL/admin/restaurant/1/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Admin GET via admin-specific route" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 8: Vendor can update their own restaurant settings
echo "========================================="
echo "Test 8: Vendor PUT /api/vendor/restaurant/1/settings (owned)"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 20,
    "hours_of_operation": {
      "monday": {"closed": false, "open": "08:00", "close": "22:00"},
      "tuesday": {"closed": false, "open": "08:00", "close": "22:00"},
      "wednesday": {"closed": false, "open": "08:00", "close": "22:00"},
      "thursday": {"closed": false, "open": "08:00", "close": "22:00"},
      "friday": {"closed": false, "open": "08:00", "close": "23:00"},
      "saturday": {"closed": false, "open": "09:00", "close": "23:00"},
      "sunday": {"closed": false, "open": "09:00", "close": "21:00"}
    }
  }')
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Vendor PUT owned restaurant settings" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Test 9: Vendor can update their own restaurant prep time
echo "========================================="
echo "Test 9: Vendor PATCH /api/vendor/restaurant/1/prep-time (owned)"
echo "========================================="
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH $BASE_URL/vendor/restaurant/1/prep-time \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"average_prep_time_minutes": 15}')
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)
print_result "Vendor PATCH owned restaurant prep time" 200 "$STATUS"
echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "========================================"
echo "All tests completed!"
echo "========================================"
