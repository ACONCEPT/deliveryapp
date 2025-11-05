#!/bin/bash

# Test script for GET /api/admin/users endpoint
# This script demonstrates all the filtering, searching, and pagination features

set -e

BASE_URL="http://localhost:8080"
API_URL="${BASE_URL}/api"

echo "========================================="
echo "Testing GET /api/admin/users Endpoint"
echo "========================================="
echo ""

# Step 1: Login as admin to get token
echo "Step 1: Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

ADMIN_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to get admin token"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "✅ Admin token obtained"
echo ""

# Step 2: Get all users (no filters)
echo "Step 2: Get all users (no filters, default pagination)..."
curl -s -X GET "${API_URL}/admin/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 3: Filter by user_type=customer
echo "Step 3: Filter by user_type=customer..."
curl -s -X GET "${API_URL}/admin/users?user_type=customer" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 4: Filter by user_type=vendor
echo "Step 4: Filter by user_type=vendor..."
curl -s -X GET "${API_URL}/admin/users?user_type=vendor" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 5: Filter by user_type=driver
echo "Step 5: Filter by user_type=driver..."
curl -s -X GET "${API_URL}/admin/users?user_type=driver" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 6: Filter by user_type=admin
echo "Step 6: Filter by user_type=admin..."
curl -s -X GET "${API_URL}/admin/users?user_type=admin" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 7: Filter by status=active
echo "Step 7: Filter by status=active..."
curl -s -X GET "${API_URL}/admin/users?status=active" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 8: Search for "customer1"
echo "Step 8: Search for 'customer1'..."
curl -s -X GET "${API_URL}/admin/users?search=customer1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 9: Pagination - page 1, per_page=2
echo "Step 9: Pagination - page 1, per_page=2..."
curl -s -X GET "${API_URL}/admin/users?page=1&per_page=2" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 10: Pagination - page 2, per_page=2
echo "Step 10: Pagination - page 2, per_page=2..."
curl -s -X GET "${API_URL}/admin/users?page=2&per_page=2" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 11: Combined filters - customer type with search
echo "Step 11: Combined filters - user_type=customer with search='1'..."
curl -s -X GET "${API_URL}/admin/users?user_type=customer&search=1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 12: Test error handling - invalid user_type
echo "Step 12: Test error handling - invalid user_type..."
curl -s -X GET "${API_URL}/admin/users?user_type=invalid" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 13: Test error handling - invalid per_page
echo "Step 13: Test error handling - invalid per_page (>100)..."
curl -s -X GET "${API_URL}/admin/users?per_page=200" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

# Step 14: Test authorization - attempt as non-admin (should fail)
echo "Step 14: Test authorization - attempt as customer (should fail with 403)..."
CUSTOMER_LOGIN=$(curl -s -X POST "${API_URL}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer1",
    "password": "password123"
  }')

CUSTOMER_TOKEN=$(echo $CUSTOMER_LOGIN | grep -o '"token":"[^"]*' | cut -d'"' -f4)

curl -s -X GET "${API_URL}/admin/users" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""
echo ""

echo "========================================="
echo "✅ All tests completed!"
echo "========================================="
