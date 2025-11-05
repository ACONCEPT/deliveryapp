#!/bin/bash

# Vendor Restaurant Settings API Test Script
# Tests GET, PUT, and PATCH endpoints for vendor restaurant settings

set -e

BASE_URL="http://localhost:8080/api"
VENDOR_TOKEN=""
RESTAURANT_ID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Vendor Restaurant Settings API Tests"
echo "======================================"
echo ""

# Step 1: Login as vendor
echo -e "${YELLOW}Step 1: Login as vendor1${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }')

VENDOR_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

if [ "$VENDOR_TOKEN" == "null" ] || [ -z "$VENDOR_TOKEN" ]; then
  echo -e "${RED}✗ Failed to login as vendor${NC}"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Logged in as vendor1${NC}"
echo "Token: ${VENDOR_TOKEN:0:20}..."
echo ""

# Step 2: Get vendor's restaurants to find a restaurant ID
echo -e "${YELLOW}Step 2: Get vendor's restaurants${NC}"
RESTAURANTS_RESPONSE=$(curl -s -X GET "$BASE_URL/restaurants" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

RESTAURANT_ID=$(echo $RESTAURANTS_RESPONSE | jq -r '.data[0].id')

if [ "$RESTAURANT_ID" == "null" ] || [ -z "$RESTAURANT_ID" ]; then
  echo -e "${RED}✗ No restaurants found for vendor${NC}"
  echo "Response: $RESTAURANTS_RESPONSE"
  exit 1
fi

RESTAURANT_NAME=$(echo $RESTAURANTS_RESPONSE | jq -r '.data[0].name')
echo -e "${GREEN}✓ Found restaurant: $RESTAURANT_NAME (ID: $RESTAURANT_ID)${NC}"
echo ""

# Step 3: GET current restaurant settings
echo -e "${YELLOW}Step 3: GET /api/vendor/restaurant/$RESTAURANT_ID/settings${NC}"
SETTINGS_RESPONSE=$(curl -s -X GET "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "Response:"
echo $SETTINGS_RESPONSE | jq '.'

SUCCESS=$(echo $SETTINGS_RESPONSE | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
  echo -e "${RED}✗ Failed to get restaurant settings${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Successfully retrieved restaurant settings${NC}"
echo ""

# Step 4: Update ONLY average prep time (PATCH)
echo -e "${YELLOW}Step 4: PATCH /api/vendor/restaurant/$RESTAURANT_ID/prep-time${NC}"
echo "Setting average prep time to 45 minutes..."
PATCH_RESPONSE=$(curl -s -X PATCH "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/prep-time" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 45
  }')

echo "Response:"
echo $PATCH_RESPONSE | jq '.'

SUCCESS=$(echo $PATCH_RESPONSE | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
  echo -e "${RED}✗ Failed to update prep time${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Successfully updated prep time${NC}"
echo ""

# Step 5: Update hours of operation and prep time (PUT)
echo -e "${YELLOW}Step 5: PUT /api/vendor/restaurant/$RESTAURANT_ID/settings${NC}"
echo "Updating hours of operation and prep time..."
PUT_RESPONSE=$(curl -s -X PUT "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 35,
    "hours_of_operation": {
      "monday": {"open": "10:00", "close": "22:00", "closed": false},
      "tuesday": {"open": "10:00", "close": "22:00", "closed": false},
      "wednesday": {"open": "10:00", "close": "22:00", "closed": false},
      "thursday": {"open": "10:00", "close": "22:00", "closed": false},
      "friday": {"open": "10:00", "close": "23:00", "closed": false},
      "saturday": {"open": "11:00", "close": "23:00", "closed": false},
      "sunday": {"open": "11:00", "close": "21:00", "closed": true}
    }
  }')

echo "Response:"
echo $PUT_RESPONSE | jq '.'

SUCCESS=$(echo $PUT_RESPONSE | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
  echo -e "${RED}✗ Failed to update settings${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Successfully updated restaurant settings${NC}"
echo ""

# Step 6: Verify updated settings
echo -e "${YELLOW}Step 6: Verify settings were updated${NC}"
VERIFY_RESPONSE=$(curl -s -X GET "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "Response:"
echo $VERIFY_RESPONSE | jq '.'

PREP_TIME=$(echo $VERIFY_RESPONSE | jq -r '.data.average_prep_time_minutes')
SUNDAY_CLOSED=$(echo $VERIFY_RESPONSE | jq -r '.data.hours_of_operation.sunday.closed')

if [ "$PREP_TIME" == "35" ] && [ "$SUNDAY_CLOSED" == "true" ]; then
  echo -e "${GREEN}✓ Settings verified successfully${NC}"
else
  echo -e "${RED}✗ Settings verification failed${NC}"
  echo "Expected prep time: 35, got: $PREP_TIME"
  echo "Expected Sunday closed: true, got: $SUNDAY_CLOSED"
  exit 1
fi
echo ""

# Step 7: Test validation - invalid prep time
echo -e "${YELLOW}Step 7: Test validation - invalid prep time (should fail)${NC}"
INVALID_RESPONSE=$(curl -s -X PATCH "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/prep-time" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 500
  }')

echo "Response:"
echo $INVALID_RESPONSE | jq '.'

SUCCESS=$(echo $INVALID_RESPONSE | jq -r '.success')
if [ "$SUCCESS" == "false" ]; then
  echo -e "${GREEN}✓ Validation correctly rejected invalid prep time${NC}"
else
  echo -e "${RED}✗ Validation failed to catch invalid prep time${NC}"
  exit 1
fi
echo ""

# Step 8: Test validation - invalid time format
echo -e "${YELLOW}Step 8: Test validation - invalid time format (should fail)${NC}"
INVALID_TIME_RESPONSE=$(curl -s -X PUT "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hours_of_operation": {
      "monday": {"open": "25:00", "close": "22:00", "closed": false},
      "tuesday": {"open": "10:00", "close": "22:00", "closed": false},
      "wednesday": {"open": "10:00", "close": "22:00", "closed": false},
      "thursday": {"open": "10:00", "close": "22:00", "closed": false},
      "friday": {"open": "10:00", "close": "23:00", "closed": false},
      "saturday": {"open": "11:00", "close": "23:00", "closed": false},
      "sunday": {"open": "11:00", "close": "21:00", "closed": false}
    }
  }')

echo "Response:"
echo $INVALID_TIME_RESPONSE | jq '.'

SUCCESS=$(echo $INVALID_TIME_RESPONSE | jq -r '.success')
if [ "$SUCCESS" == "false" ]; then
  echo -e "${GREEN}✓ Validation correctly rejected invalid time format${NC}"
else
  echo -e "${RED}✗ Validation failed to catch invalid time format${NC}"
  exit 1
fi
echo ""

# Step 9: Test unauthorized access (try to access another vendor's restaurant)
echo -e "${YELLOW}Step 9: Test unauthorized access (should fail)${NC}"
# Login as a different user (customer)
CUSTOMER_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer1",
    "password": "password123"
  }')

CUSTOMER_TOKEN=$(echo $CUSTOMER_RESPONSE | jq -r '.token')

UNAUTHORIZED_RESPONSE=$(curl -s -X GET "$BASE_URL/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN")

echo "Response:"
echo $UNAUTHORIZED_RESPONSE | jq '.'

SUCCESS=$(echo $UNAUTHORIZED_RESPONSE | jq -r '.success')
if [ "$SUCCESS" == "false" ]; then
  echo -e "${GREEN}✓ Access correctly denied to non-vendor user${NC}"
else
  echo -e "${RED}✗ Authorization check failed${NC}"
  exit 1
fi
echo ""

# Summary
echo "======================================"
echo -e "${GREEN}All tests passed!${NC}"
echo "======================================"
echo ""
echo "Test Summary:"
echo "✓ Vendor login"
echo "✓ Get restaurant settings"
echo "✓ Update prep time only (PATCH)"
echo "✓ Update full settings (PUT)"
echo "✓ Verify settings updated"
echo "✓ Validation - invalid prep time"
echo "✓ Validation - invalid time format"
echo "✓ Authorization - non-vendor access denied"
echo ""
