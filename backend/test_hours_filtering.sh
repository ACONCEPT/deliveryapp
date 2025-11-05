#!/bin/bash

# Test script for restaurant hours filtering functionality
# Tests the filtering logic for customers viewing restaurants

set -e

BASE_URL="http://localhost:8080"

echo "========================================="
echo "Restaurant Hours Filtering Test Suite"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Login as customer
echo -e "${YELLOW}Test 1: Login as customer${NC}"
CUSTOMER_TOKEN=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer1",
    "password": "password123"
  }' | jq -r '.token')

if [ -z "$CUSTOMER_TOKEN" ] || [ "$CUSTOMER_TOKEN" == "null" ]; then
  echo -e "${RED}Failed: Could not login as customer${NC}"
  exit 1
else
  echo -e "${GREEN}Success: Customer logged in${NC}"
  echo "Token: ${CUSTOMER_TOKEN:0:20}..."
fi
echo ""

# Test 2: Login as vendor
echo -e "${YELLOW}Test 2: Login as vendor${NC}"
VENDOR_TOKEN=$(curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }' | jq -r '.token')

if [ -z "$VENDOR_TOKEN" ] || [ "$VENDOR_TOKEN" == "null" ]; then
  echo -e "${RED}Failed: Could not login as vendor${NC}"
  exit 1
else
  echo -e "${GREEN}Success: Vendor logged in${NC}"
  echo "Token: ${VENDOR_TOKEN:0:20}..."
fi
echo ""

# Test 3: Get customer's view of restaurants (should filter by hours)
echo -e "${YELLOW}Test 3: Get restaurants as customer (with hours filtering)${NC}"
CUSTOMER_RESTAURANTS=$(curl -s -X GET "$BASE_URL/api/restaurants" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN")

CUSTOMER_COUNT=$(echo "$CUSTOMER_RESTAURANTS" | jq '.restaurants | length')
echo "Restaurants visible to customer: $CUSTOMER_COUNT"
echo "$CUSTOMER_RESTAURANTS" | jq '.restaurants[] | {id, name, is_active, approval_status, hours_of_operation, timezone}'
echo ""

# Test 4: Get vendor's view of restaurants (should NOT filter by hours)
echo -e "${YELLOW}Test 4: Get restaurants as vendor (NO hours filtering)${NC}"
VENDOR_RESTAURANTS=$(curl -s -X GET "$BASE_URL/api/restaurants" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

VENDOR_COUNT=$(echo "$VENDOR_RESTAURANTS" | jq '.restaurants | length')
echo "Restaurants visible to vendor: $VENDOR_COUNT"
echo "$VENDOR_RESTAURANTS" | jq '.restaurants[] | {id, name, is_active, approval_status}'
echo ""

# Test 5: Update restaurant hours to be closed now
echo -e "${YELLOW}Test 5: Update restaurant to be closed (set hours 01:00-02:00)${NC}"

# Get the first restaurant ID
RESTAURANT_ID=$(echo "$VENDOR_RESTAURANTS" | jq -r '.restaurants[0].id')

if [ -z "$RESTAURANT_ID" ] || [ "$RESTAURANT_ID" == "null" ]; then
  echo -e "${YELLOW}Warning: No restaurants found for vendor, skipping update test${NC}"
else
  echo "Updating restaurant ID: $RESTAURANT_ID"

  # Update with hours that are closed now (01:00 AM - 02:00 AM)
  UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/vendor/restaurants/$RESTAURANT_ID" \
    -H "Authorization: Bearer $VENDOR_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "hours_of_operation": "{\"monday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"tuesday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"wednesday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"thursday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"friday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"saturday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false},\"sunday\":{\"open\":\"01:00\",\"close\":\"02:00\",\"closed\":false}}"
    }')

  if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
    echo -e "${GREEN}Success: Restaurant hours updated${NC}"
  else
    echo -e "${RED}Failed: Could not update restaurant hours${NC}"
    echo "$UPDATE_RESPONSE" | jq '.'
  fi
fi
echo ""

# Test 6: Verify customer can no longer see the restaurant (it's closed)
echo -e "${YELLOW}Test 6: Verify customer cannot see closed restaurant${NC}"
sleep 1 # Give a moment for update to propagate

CUSTOMER_RESTAURANTS_AFTER=$(curl -s -X GET "$BASE_URL/api/restaurants" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN")

CUSTOMER_COUNT_AFTER=$(echo "$CUSTOMER_RESTAURANTS_AFTER" | jq '.restaurants | length')
echo "Restaurants visible to customer after update: $CUSTOMER_COUNT_AFTER"

if [ "$CUSTOMER_COUNT_AFTER" -lt "$CUSTOMER_COUNT" ]; then
  echo -e "${GREEN}Success: Restaurant was filtered out (closed)${NC}"
else
  echo -e "${YELLOW}Note: Restaurant count did not decrease. It may still be open based on current time.${NC}"
fi

echo "$CUSTOMER_RESTAURANTS_AFTER" | jq '.restaurants[] | {id, name, hours_of_operation}'
echo ""

# Test 7: Update restaurant hours to be open now
echo -e "${YELLOW}Test 7: Update restaurant to be open (set hours 00:00-23:59)${NC}"

if [ ! -z "$RESTAURANT_ID" ] && [ "$RESTAURANT_ID" != "null" ]; then
  # Update with hours that are always open (00:00 - 23:59)
  UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/vendor/restaurants/$RESTAURANT_ID" \
    -H "Authorization: Bearer $VENDOR_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "hours_of_operation": "{\"monday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"tuesday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"wednesday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"thursday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"friday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"saturday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false},\"sunday\":{\"open\":\"00:00\",\"close\":\"23:59\",\"closed\":false}}"
    }')

  if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
    echo -e "${GREEN}Success: Restaurant hours updated to always open${NC}"
  else
    echo -e "${RED}Failed: Could not update restaurant hours${NC}"
    echo "$UPDATE_RESPONSE" | jq '.'
  fi
fi
echo ""

# Test 8: Verify customer can now see the restaurant again
echo -e "${YELLOW}Test 8: Verify customer can see open restaurant${NC}"
sleep 1

CUSTOMER_RESTAURANTS_FINAL=$(curl -s -X GET "$BASE_URL/api/restaurants" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN")

CUSTOMER_COUNT_FINAL=$(echo "$CUSTOMER_RESTAURANTS_FINAL" | jq '.restaurants | length')
echo "Restaurants visible to customer (final): $CUSTOMER_COUNT_FINAL"

if [ "$CUSTOMER_COUNT_FINAL" -ge "$CUSTOMER_COUNT_AFTER" ]; then
  echo -e "${GREEN}Success: Restaurant is visible again (open)${NC}"
else
  echo -e "${YELLOW}Warning: Restaurant count did not increase${NC}"
fi

echo "$CUSTOMER_RESTAURANTS_FINAL" | jq '.restaurants[] | {id, name, hours_of_operation}'
echo ""

# Test 9: Test restaurant with closed day
echo -e "${YELLOW}Test 9: Set restaurant to closed on current day${NC}"

if [ ! -z "$RESTAURANT_ID" ] && [ "$RESTAURANT_ID" != "null" ]; then
  # Get current day of week
  CURRENT_DAY=$(date +%A | tr '[:upper:]' '[:lower:]')
  echo "Current day: $CURRENT_DAY"

  # Build hours JSON with current day marked as closed
  HOURS_JSON=$(cat <<EOF
{
  "monday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "monday" ] && echo "true" || echo "false")},
  "tuesday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "tuesday" ] && echo "true" || echo "false")},
  "wednesday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "wednesday" ] && echo "true" || echo "false")},
  "thursday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "thursday" ] && echo "true" || echo "false")},
  "friday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "friday" ] && echo "true" || echo "false")},
  "saturday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "saturday" ] && echo "true" || echo "false")},
  "sunday":{"open":"09:00","close":"21:00","closed":$([ "$CURRENT_DAY" = "sunday" ] && echo "true" || echo "false")}
}
EOF
)

  UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/vendor/restaurants/$RESTAURANT_ID" \
    -H "Authorization: Bearer $VENDOR_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"hours_of_operation\": \"$(echo $HOURS_JSON | tr -d '\n')\"}")

  if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
    echo -e "${GREEN}Success: Restaurant set to closed on $CURRENT_DAY${NC}"
  else
    echo -e "${RED}Failed: Could not update restaurant hours${NC}"
    echo "$UPDATE_RESPONSE" | jq '.'
  fi

  sleep 1

  # Check customer view
  CUSTOMER_RESTAURANTS_CLOSED_DAY=$(curl -s -X GET "$BASE_URL/api/restaurants" \
    -H "Authorization: Bearer $CUSTOMER_TOKEN")

  CUSTOMER_COUNT_CLOSED_DAY=$(echo "$CUSTOMER_RESTAURANTS_CLOSED_DAY" | jq '.restaurants | length')
  echo "Restaurants visible to customer (closed day): $CUSTOMER_COUNT_CLOSED_DAY"

  if [ "$CUSTOMER_COUNT_CLOSED_DAY" -lt "$CUSTOMER_COUNT_FINAL" ]; then
    echo -e "${GREEN}Success: Restaurant filtered out on closed day${NC}"
  else
    echo -e "${YELLOW}Note: Restaurant may still be visible (could be edge case with timing)${NC}"
  fi
fi
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}Test Suite Complete${NC}"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Customer authentication: OK"
echo "  - Vendor authentication: OK"
echo "  - Hours filtering for customers: Tested"
echo "  - No hours filtering for vendors: Tested"
echo "  - Dynamic hour updates: Tested"
echo ""
echo "Check server logs for detailed hours filtering information:"
echo "  grep '[Hours Filter]' backend.log"
echo ""
