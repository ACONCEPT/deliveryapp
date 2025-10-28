#!/bin/bash

# Test script for System Settings API endpoints
# This script tests all the new configuration management endpoints

set -e

BASE_URL="http://localhost:8080"
ADMIN_TOKEN=""
API_BASE="${BASE_URL}/api"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "System Settings API Test Script"
echo "=========================================="
echo ""

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
    fi
}

# Function to make authenticated request
auth_request() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            "${API_BASE}${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${API_BASE}${endpoint}"
    fi
}

# Step 1: Login as admin
echo "Step 1: Login as admin..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_BASE}/login" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "admin1",
        "password": "password123"
    }')

ADMIN_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}Failed to login as admin${NC}"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

print_result 0 "Admin login successful"
echo ""

# Step 2: Get all settings
echo "Step 2: Get all system settings..."
ALL_SETTINGS=$(auth_request "GET" "/admin/settings")
TOTAL_COUNT=$(echo "$ALL_SETTINGS" | grep -o '"total_count":[0-9]*' | sed 's/"total_count"://')

if [ "$TOTAL_COUNT" -gt 0 ]; then
    print_result 0 "Retrieved $TOTAL_COUNT settings"
else
    print_result 1 "Failed to retrieve settings"
fi
echo ""

# Step 3: Get categories
echo "Step 3: Get all categories..."
CATEGORIES=$(auth_request "GET" "/admin/settings/categories")
CAT_COUNT=$(echo "$CATEGORIES" | grep -o '"count":[0-9]*' | sed 's/"count"://')

if [ "$CAT_COUNT" -gt 0 ]; then
    print_result 0 "Retrieved $CAT_COUNT categories"
    echo "Categories response: $CATEGORIES"
else
    print_result 1 "Failed to retrieve categories"
fi
echo ""

# Step 4: Get settings by category
echo "Step 4: Get settings by category (orders)..."
ORDER_SETTINGS=$(auth_request "GET" "/admin/settings?category=orders")
ORDER_COUNT=$(echo "$ORDER_SETTINGS" | grep -o '"total_count":[0-9]*' | sed 's/"total_count"://')

if [ "$ORDER_COUNT" -gt 0 ]; then
    print_result 0 "Retrieved $ORDER_COUNT order settings"
else
    print_result 1 "Failed to retrieve order settings"
fi
echo ""

# Step 5: Get specific setting
echo "Step 5: Get specific setting (tax_rate)..."
TAX_RATE=$(auth_request "GET" "/admin/settings/tax_rate")
TAX_VALUE=$(echo "$TAX_RATE" | grep -o '"setting_value":"[^"]*' | sed 's/"setting_value":"//')

if [ -n "$TAX_VALUE" ]; then
    print_result 0 "Retrieved tax_rate setting: $TAX_VALUE"
else
    print_result 1 "Failed to retrieve tax_rate setting"
fi
echo ""

# Step 6: Update single setting
echo "Step 6: Update single setting (tax_rate to 0.09)..."
UPDATE_RESPONSE=$(auth_request "PUT" "/admin/settings/tax_rate" '{"value": "0.09"}')
UPDATE_SUCCESS=$(echo "$UPDATE_RESPONSE" | grep -o '"success":true')

if [ -n "$UPDATE_SUCCESS" ]; then
    print_result 0 "Updated tax_rate to 0.09"

    # Verify the update
    VERIFY=$(auth_request "GET" "/admin/settings/tax_rate")
    NEW_VALUE=$(echo "$VERIFY" | grep -o '"setting_value":"[^"]*' | sed 's/"setting_value":"//')

    if [ "$NEW_VALUE" = "0.09" ]; then
        print_result 0 "Verified tax_rate is now 0.09"
    else
        print_result 1 "Tax rate not updated correctly (got: $NEW_VALUE)"
    fi
else
    print_result 1 "Failed to update tax_rate"
    echo "Response: $UPDATE_RESPONSE"
fi
echo ""

# Step 7: Update multiple settings
echo "Step 7: Update multiple settings (batch update)..."
BATCH_UPDATE=$(auth_request "PUT" "/admin/settings" '{
    "settings": [
        {"key": "minimum_order_amount", "value": "15.00"},
        {"key": "default_delivery_fee", "value": "6.00"}
    ]
}')
BATCH_SUCCESS=$(echo "$BATCH_UPDATE" | grep -o '"success_count":[0-9]*' | sed 's/"success_count"://')

if [ "$BATCH_SUCCESS" = "2" ]; then
    print_result 0 "Batch update successful: 2 settings updated"
else
    print_result 1 "Batch update failed"
    echo "Response: $BATCH_UPDATE"
fi
echo ""

# Step 8: Verify batch updates
echo "Step 8: Verify batch updates..."
MIN_ORDER=$(auth_request "GET" "/admin/settings/minimum_order_amount")
MIN_VALUE=$(echo "$MIN_ORDER" | grep -o '"setting_value":"[^"]*' | sed 's/"setting_value":"//')

DELIVERY_FEE=$(auth_request "GET" "/admin/settings/default_delivery_fee")
FEE_VALUE=$(echo "$DELIVERY_FEE" | grep -o '"setting_value":"[^"]*' | sed 's/"setting_value":"//')

if [ "$MIN_VALUE" = "15.00" ] && [ "$FEE_VALUE" = "6.00" ]; then
    print_result 0 "Batch updates verified: min_order=$MIN_VALUE, delivery_fee=$FEE_VALUE"
else
    print_result 1 "Batch updates not verified correctly"
fi
echo ""

# Step 9: Test validation - invalid number
echo "Step 9: Test validation (invalid number)..."
INVALID_UPDATE=$(auth_request "PUT" "/admin/settings/tax_rate" '{"value": "not_a_number"}')
VALIDATION_ERROR=$(echo "$INVALID_UPDATE" | grep -o '"success":false')

if [ -n "$VALIDATION_ERROR" ]; then
    print_result 0 "Validation correctly rejected invalid number"
else
    print_result 1 "Validation should have rejected invalid number"
fi
echo ""

# Step 10: Test validation - out of range
echo "Step 10: Test validation (tax rate out of range)..."
OUT_OF_RANGE=$(auth_request "PUT" "/admin/settings/tax_rate" '{"value": "1.5"}')
RANGE_ERROR=$(echo "$OUT_OF_RANGE" | grep -o '"success":false')

if [ -n "$RANGE_ERROR" ]; then
    print_result 0 "Validation correctly rejected out-of-range value"
else
    print_result 1 "Validation should have rejected out-of-range value"
fi
echo ""

# Step 11: Test read-only setting
echo "Step 11: Test read-only setting (business_name)..."
READONLY_UPDATE=$(auth_request "PUT" "/admin/settings/business_name" '{"value": "NewName"}')
READONLY_ERROR=$(echo "$READONLY_UPDATE" | grep -o 'read-only')

if [ -n "$READONLY_ERROR" ]; then
    print_result 0 "Correctly prevented update of read-only setting"
else
    print_result 1 "Should have prevented update of read-only setting"
fi
echo ""

# Step 12: Restore original values
echo "Step 12: Restore original values..."
RESTORE=$(auth_request "PUT" "/admin/settings" '{
    "settings": [
        {"key": "tax_rate", "value": "0.085"},
        {"key": "minimum_order_amount", "value": "10.00"},
        {"key": "default_delivery_fee", "value": "5.00"}
    ]
}')
RESTORE_SUCCESS=$(echo "$RESTORE" | grep -o '"success_count":3')

if [ -n "$RESTORE_SUCCESS" ]; then
    print_result 0 "Original values restored"
else
    print_result 1 "Failed to restore original values"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}All system settings tests completed!${NC}"
echo ""
echo "Available settings categories:"
echo "  - orders: minimum_order_amount, tax_rate, order_auto_cancel_minutes"
echo "  - payments: platform_commission_rate, driver_commission_rate"
echo "  - delivery: max_delivery_radius_km, estimated_prep_time_default"
echo "  - system: maintenance_mode, allow_new_registrations"
echo "  - business: support_email, support_phone, business_name"
echo ""
echo "API Endpoints:"
echo "  GET    /api/admin/settings                  - Get all settings"
echo "  GET    /api/admin/settings?category=orders  - Filter by category"
echo "  GET    /api/admin/settings/categories       - Get all categories"
echo "  GET    /api/admin/settings/{key}            - Get specific setting"
echo "  PUT    /api/admin/settings/{key}            - Update single setting"
echo "  PUT    /api/admin/settings                  - Batch update settings"
echo ""
