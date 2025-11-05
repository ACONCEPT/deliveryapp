#!/bin/bash
set -e

BASE_URL="http://localhost:8080/api"

# Login as admin
echo "Logging in as admin..."
ADMIN_RESPONSE=$(curl -s -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin1", "password": "password123"}')

ADMIN_TOKEN=$(echo $ADMIN_RESPONSE | jq -r '.token')
echo "Admin token obtained: ${ADMIN_TOKEN:0:50}..."
echo ""

# Test admin access to vendor route
echo "Testing admin access to /api/vendor/restaurant/1/settings..."
curl -s -X GET $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'
echo ""

echo "Testing admin update to /api/vendor/restaurant/1/prep-time..."
curl -s -X PATCH $BASE_URL/vendor/restaurant/1/prep-time \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"average_prep_time_minutes": 30}' | jq '.'
echo ""

# Login as customer (should fail)
echo "Logging in as customer..."
CUSTOMER_RESPONSE=$(curl -s -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "customer1", "password": "password123"}')

CUSTOMER_TOKEN=$(echo $CUSTOMER_RESPONSE | jq -r '.token')
echo "Customer token obtained"
echo ""

echo "Testing customer access to vendor route (should fail with 403)..."
curl -s -X GET $BASE_URL/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $CUSTOMER_TOKEN" | jq '.'
echo ""

echo "All tests completed!"
