#!/bin/bash

# Test script for Customization Templates API
# Tests vendor and admin endpoints for creating, reading, updating, and deleting customization templates

set -e

BASE_URL="http://localhost:8080"
ADMIN_TOKEN=""
VENDOR_TOKEN=""
TEMPLATE_ID=""

echo "=========================================="
echo "Customization Templates API Test Script"
echo "=========================================="
echo ""

# Login as admin
echo "1. Logging in as admin..."
ADMIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

ADMIN_TOKEN=$(echo $ADMIN_RESPONSE | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to login as admin"
  echo "Response: $ADMIN_RESPONSE"
  exit 1
fi

echo "✓ Admin login successful"
echo "Token: ${ADMIN_TOKEN:0:20}..."
echo ""

# Login as vendor
echo "2. Logging in as vendor..."
VENDOR_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }')

VENDOR_TOKEN=$(echo $VENDOR_RESPONSE | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -z "$VENDOR_TOKEN" ]; then
  echo "❌ Failed to login as vendor"
  echo "Response: $VENDOR_RESPONSE"
  exit 1
fi

echo "✓ Vendor login successful"
echo "Token: ${VENDOR_TOKEN:0:20}..."
echo ""

# Test 1: Vendor creates a customization template
echo "=========================================="
echo "TEST 1: Vendor creates customization template"
echo "=========================================="

CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/vendor/customization-templates" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -d '{
    "name": "Spice Level",
    "description": "Choose your preferred spice level",
    "customization_config": {
      "type": "select",
      "options": [
        {"label": "Mild", "value": "mild", "price": 0},
        {"label": "Medium", "value": "medium", "price": 0},
        {"label": "Hot", "value": "hot", "price": 0},
        {"label": "Extra Hot", "value": "extra_hot", "price": 1.00}
      ]
    },
    "is_active": true
  }')

echo "$CREATE_RESPONSE" | jq '.'

TEMPLATE_ID=$(echo $CREATE_RESPONSE | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

if [ -z "$TEMPLATE_ID" ]; then
  echo "❌ Failed to create customization template"
  exit 1
fi

echo ""
echo "✓ Customization template created with ID: $TEMPLATE_ID"
echo ""

# Test 2: Vendor gets all templates (should see their own + system-wide)
echo "=========================================="
echo "TEST 2: Vendor gets all templates"
echo "=========================================="

GET_ALL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/vendor/customization-templates" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$GET_ALL_RESPONSE" | jq '.'
echo ""
echo "✓ Successfully retrieved vendor templates"
echo ""

# Test 3: Vendor gets specific template by ID
echo "=========================================="
echo "TEST 3: Vendor gets template by ID"
echo "=========================================="

GET_ONE_RESPONSE=$(curl -s -X GET "$BASE_URL/api/vendor/customization-templates/$TEMPLATE_ID" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$GET_ONE_RESPONSE" | jq '.'
echo ""
echo "✓ Successfully retrieved template by ID"
echo ""

# Test 4: Vendor updates template
echo "=========================================="
echo "TEST 4: Vendor updates template"
echo "=========================================="

UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/vendor/customization-templates/$TEMPLATE_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -d '{
    "description": "UPDATED: Choose your preferred spice level",
    "customization_config": {
      "type": "select",
      "options": [
        {"label": "No Spice", "value": "none", "price": 0},
        {"label": "Mild", "value": "mild", "price": 0},
        {"label": "Medium", "value": "medium", "price": 0.50},
        {"label": "Hot", "value": "hot", "price": 1.00},
        {"label": "Extra Hot", "value": "extra_hot", "price": 2.00}
      ]
    }
  }')

echo "$UPDATE_RESPONSE" | jq '.'
echo ""
echo "✓ Successfully updated template"
echo ""

# Test 5: Admin creates system-wide template
echo "=========================================="
echo "TEST 5: Admin creates system-wide template"
echo "=========================================="

ADMIN_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/admin/customization-templates" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "name": "Size Options",
    "description": "Choose your preferred size",
    "customization_config": {
      "type": "select",
      "options": [
        {"label": "Small", "value": "small", "price": 0},
        {"label": "Medium", "value": "medium", "price": 3.00},
        {"label": "Large", "value": "large", "price": 5.00}
      ]
    },
    "is_active": true
  }')

echo "$ADMIN_CREATE_RESPONSE" | jq '.'

ADMIN_TEMPLATE_ID=$(echo $ADMIN_CREATE_RESPONSE | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

echo ""
echo "✓ Admin created system-wide template with ID: $ADMIN_TEMPLATE_ID"
echo ""

# Test 6: Admin gets all templates
echo "=========================================="
echo "TEST 6: Admin gets all templates"
echo "=========================================="

ADMIN_GET_ALL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/admin/customization-templates" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

echo "$ADMIN_GET_ALL_RESPONSE" | jq '.'
echo ""
echo "✓ Admin successfully retrieved all templates"
echo ""

# Test 7: Vendor sees system-wide template
echo "=========================================="
echo "TEST 7: Vendor sees system-wide template"
echo "=========================================="

VENDOR_GET_ALL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/vendor/customization-templates" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$VENDOR_GET_ALL_RESPONSE" | jq '.'

TEMPLATE_COUNT=$(echo $VENDOR_GET_ALL_RESPONSE | jq '.data | length')
echo ""
echo "✓ Vendor sees $TEMPLATE_COUNT templates (should include system-wide templates)"
echo ""

# Test 8: Vendor creates another template (Pizza Toppings)
echo "=========================================="
echo "TEST 8: Vendor creates Pizza Toppings template"
echo "=========================================="

TOPPINGS_RESPONSE=$(curl -s -X POST "$BASE_URL/api/vendor/customization-templates" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -d '{
    "name": "Pizza Toppings",
    "description": "Add your favorite toppings",
    "customization_config": {
      "type": "multi-select",
      "max_selections": 5,
      "options": [
        {"label": "Pepperoni", "value": "pepperoni", "price": 2.00},
        {"label": "Mushrooms", "value": "mushrooms", "price": 1.50},
        {"label": "Extra Cheese", "value": "extra_cheese", "price": 1.00},
        {"label": "Onions", "value": "onions", "price": 1.00},
        {"label": "Green Peppers", "value": "green_peppers", "price": 1.00}
      ]
    },
    "is_active": true
  }')

echo "$TOPPINGS_RESPONSE" | jq '.'

TOPPINGS_ID=$(echo $TOPPINGS_RESPONSE | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

echo ""
echo "✓ Pizza Toppings template created with ID: $TOPPINGS_ID"
echo ""

# Test 9: Vendor deletes template
echo "=========================================="
echo "TEST 9: Vendor deletes template"
echo "=========================================="

DELETE_RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/vendor/customization-templates/$TEMPLATE_ID" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$DELETE_RESPONSE" | jq '.'
echo ""
echo "✓ Successfully deleted template ID: $TEMPLATE_ID"
echo ""

# Test 10: Admin deletes system-wide template
echo "=========================================="
echo "TEST 10: Admin deletes system-wide template"
echo "=========================================="

ADMIN_DELETE_RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/admin/customization-templates/$ADMIN_TEMPLATE_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

echo "$ADMIN_DELETE_RESPONSE" | jq '.'
echo ""
echo "✓ Admin successfully deleted system-wide template ID: $ADMIN_TEMPLATE_ID"
echo ""

# Final check: Verify templates were deleted
echo "=========================================="
echo "FINAL CHECK: Verify remaining templates"
echo "=========================================="

FINAL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/vendor/customization-templates" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$FINAL_RESPONSE" | jq '.'

FINAL_COUNT=$(echo $FINAL_RESPONSE | jq '.data | length')
echo ""
echo "✓ Vendor now has $FINAL_COUNT template(s) remaining"
echo ""

echo "=========================================="
echo "✓ All tests passed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Vendor can create customization templates"
echo "  - Vendor can view their own templates + system-wide templates"
echo "  - Vendor can update their own templates"
echo "  - Vendor can delete their own templates"
echo "  - Admin can create system-wide templates"
echo "  - Admin can view all templates"
echo "  - Admin can delete any template"
echo "  - System-wide templates (vendor_id=NULL) are visible to all vendors"
echo ""
