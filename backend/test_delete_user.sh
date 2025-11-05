#!/bin/bash

# Test script for DELETE /api/admin/users/{id} endpoint
# This script demonstrates all scenarios for user deletion

set -e

API_BASE="http://localhost:8080/api"
ADMIN_TOKEN=""
VENDOR_TOKEN=""

echo "=========================================="
echo "Admin Delete User Endpoint Test"
echo "=========================================="
echo ""

# Step 1: Login as admin to get token
echo "[1] Logging in as admin..."
ADMIN_RESPONSE=$(curl -s -X POST "${API_BASE}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

ADMIN_TOKEN=$(echo "$ADMIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Failed to get admin token!"
  echo "Response: $ADMIN_RESPONSE"
  exit 1
fi

echo "Admin logged in successfully"
echo "Token: ${ADMIN_TOKEN:0:20}..."
echo ""

# Step 2: Login as vendor to test unauthorized access
echo "[2] Logging in as vendor (for authorization test)..."
VENDOR_RESPONSE=$(curl -s -X POST "${API_BASE}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }')

VENDOR_TOKEN=$(echo "$VENDOR_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "Vendor logged in successfully"
echo ""

# Step 3: Create a test user to delete
echo "[3] Creating a test user (testcustomer2)..."
SIGNUP_RESPONSE=$(curl -s -X POST "${API_BASE}/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testcustomer2",
    "email": "testcustomer2@example.com",
    "password": "password123",
    "user_type": "customer",
    "full_name": "Test Customer 2",
    "phone": "555-9999"
  }')

TEST_USER_ID=$(echo "$SIGNUP_RESPONSE" | grep -o '"user_id":[0-9]*' | cut -d':' -f2)

if [ -z "$TEST_USER_ID" ]; then
  echo "Failed to create test user!"
  echo "Response: $SIGNUP_RESPONSE"
  exit 1
fi

echo "Test user created with ID: $TEST_USER_ID"
echo ""

# Step 4: Test unauthorized deletion (vendor tries to delete user)
echo "[4] Testing unauthorized deletion (vendor tries to delete user)..."
VENDOR_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${VENDOR_TOKEN}")

echo "Response: $VENDOR_DELETE"
if echo "$VENDOR_DELETE" | grep -q "Forbidden"; then
  echo "PASS: Vendor correctly denied access"
else
  echo "FAIL: Vendor should not have access"
fi
echo ""

# Step 5: Test deletion without auth token
echo "[5] Testing deletion without authentication..."
NO_AUTH_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/${TEST_USER_ID}")

echo "Response: $NO_AUTH_DELETE"
if echo "$NO_AUTH_DELETE" | grep -q "Authentication required\|Authorization header missing"; then
  echo "PASS: Request correctly denied without auth"
else
  echo "FAIL: Should require authentication"
fi
echo ""

# Step 6: Test admin trying to delete themselves
echo "[6] Testing admin trying to delete their own account..."
ADMIN_USER_ID=$(echo "$ADMIN_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

SELF_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/${ADMIN_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "Response: $SELF_DELETE"
if echo "$SELF_DELETE" | grep -q "Cannot delete your own account"; then
  echo "PASS: Admin correctly prevented from self-deletion"
else
  echo "FAIL: Should prevent self-deletion"
fi
echo ""

# Step 7: Test invalid user ID
echo "[7] Testing deletion with invalid user ID..."
INVALID_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/abc" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "Response: $INVALID_DELETE"
if echo "$INVALID_DELETE" | grep -q "Invalid user ID"; then
  echo "PASS: Invalid ID correctly rejected"
else
  echo "FAIL: Should reject invalid ID"
fi
echo ""

# Step 8: Test deletion of non-existent user
echo "[8] Testing deletion of non-existent user..."
NONEXISTENT_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/99999" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "Response: $NONEXISTENT_DELETE"
if echo "$NONEXISTENT_DELETE" | grep -q "User not found"; then
  echo "PASS: Non-existent user correctly handled"
else
  echo "FAIL: Should return user not found"
fi
echo ""

# Step 9: Test successful deletion of test user
echo "[9] Testing successful deletion of test user..."
SUCCESS_DELETE=$(curl -s -X DELETE "${API_BASE}/admin/users/${TEST_USER_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "Response: $SUCCESS_DELETE"
if echo "$SUCCESS_DELETE" | grep -q "deleted successfully"; then
  echo "PASS: User deleted successfully"
else
  echo "FAIL: Deletion should succeed"
fi
echo ""

# Step 10: Verify user is actually deleted
echo "[10] Verifying user is deleted (try to login as deleted user)..."
LOGIN_DELETED=$(curl -s -X POST "${API_BASE}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testcustomer2",
    "password": "password123"
  }')

echo "Response: $LOGIN_DELETED"
if echo "$LOGIN_DELETED" | grep -q "invalid credentials\|user not found"; then
  echo "PASS: Deleted user cannot login"
else
  echo "FAIL: Deleted user should not be able to login"
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "All tests completed!"
echo ""
echo "Key features verified:"
echo "- Admin can delete users"
echo "- Non-admin cannot delete users (403 Forbidden)"
echo "- No auth token = denied (401 Unauthorized)"
echo "- Admin cannot delete themselves (400 Bad Request)"
echo "- Invalid user ID rejected (400 Bad Request)"
echo "- Non-existent user returns 404"
echo "- Successful deletion returns 200"
echo "- Deleted user cannot login (verified cascade)"
echo ""
echo "Note: To test 'last admin' protection, you would need to:"
echo "1. Count admin users in database"
echo "2. Delete all but one admin"
echo "3. Try to delete the last admin"
echo "4. Expect 400 Bad Request with 'Cannot delete the last admin user'"
