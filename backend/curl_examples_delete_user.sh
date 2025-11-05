#!/bin/bash

# Quick curl examples for DELETE /api/admin/users/{id}
# Make sure the backend is running on http://localhost:8080

API_BASE="http://localhost:8080/api"

echo "=========================================="
echo "DELETE User Endpoint - Quick Examples"
echo "=========================================="
echo ""

# First, login as admin to get token
echo "Step 1: Login as admin"
echo "Command:"
echo "curl -X POST ${API_BASE}/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"username\": \"admin1\", \"password\": \"password123\"}'"
echo ""

read -p "Press Enter to execute..."

RESPONSE=$(curl -s -X POST "${API_BASE}/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

echo "Response:"
echo "$RESPONSE" | jq '.'
echo ""

TOKEN=$(echo "$RESPONSE" | jq -r '.data.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "Failed to get token. Make sure admin1 exists with password 'password123'"
  exit 1
fi

echo "Token obtained: ${TOKEN:0:30}..."
echo ""
echo "=========================================="

# Example 1: Try to delete yourself (should fail)
echo ""
echo "Example 1: Admin tries to delete their own account (SHOULD FAIL)"
USER_ID=$(echo "$RESPONSE" | jq -r '.data.user.id')
echo "Your admin user ID: $USER_ID"
echo ""
echo "Command:"
echo "curl -X DELETE ${API_BASE}/admin/users/${USER_ID} \\"
echo "  -H 'Authorization: Bearer \$TOKEN'"
echo ""

read -p "Press Enter to execute..."

DELETE_SELF=$(curl -s -X DELETE "${API_BASE}/admin/users/${USER_ID}" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Response:"
echo "$DELETE_SELF" | jq '.'
echo ""
echo "Expected: 400 Bad Request with message 'Cannot delete your own account'"
echo "=========================================="

# Example 2: Delete with invalid ID (should fail)
echo ""
echo "Example 2: Delete with invalid user ID format (SHOULD FAIL)"
echo ""
echo "Command:"
echo "curl -X DELETE ${API_BASE}/admin/users/abc \\"
echo "  -H 'Authorization: Bearer \$TOKEN'"
echo ""

read -p "Press Enter to execute..."

DELETE_INVALID=$(curl -s -X DELETE "${API_BASE}/admin/users/abc" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Response:"
echo "$DELETE_INVALID" | jq '.'
echo ""
echo "Expected: 400 Bad Request with message 'Invalid user ID'"
echo "=========================================="

# Example 3: Delete non-existent user (should fail)
echo ""
echo "Example 3: Delete non-existent user ID (SHOULD FAIL)"
echo ""
echo "Command:"
echo "curl -X DELETE ${API_BASE}/admin/users/99999 \\"
echo "  -H 'Authorization: Bearer \$TOKEN'"
echo ""

read -p "Press Enter to execute..."

DELETE_NOTFOUND=$(curl -s -X DELETE "${API_BASE}/admin/users/99999" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Response:"
echo "$DELETE_NOTFOUND" | jq '.'
echo ""
echo "Expected: 404 Not Found with message 'User not found'"
echo "=========================================="

# Example 4: Create a test user and delete it (should succeed)
echo ""
echo "Example 4: Create test user and delete it (SHOULD SUCCEED)"
echo ""
echo "First, create a test user..."

SIGNUP=$(curl -s -X POST "${API_BASE}/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "delete_test_user",
    "email": "deletetest@example.com",
    "password": "password123",
    "user_type": "customer",
    "full_name": "Delete Test User",
    "phone": "555-1234"
  }')

echo "Signup response:"
echo "$SIGNUP" | jq '.'
echo ""

TEST_USER_ID=$(echo "$SIGNUP" | jq -r '.data.user_id')

if [ -z "$TEST_USER_ID" ] || [ "$TEST_USER_ID" == "null" ]; then
  echo "Note: User might already exist. Trying to get user ID..."
  # If signup failed because user exists, we can still demonstrate delete
  # For demo purposes, we'll skip this
  echo "Skipping successful delete demo."
else
  echo "Test user created with ID: $TEST_USER_ID"
  echo ""
  echo "Now deleting the test user..."
  echo ""
  echo "Command:"
  echo "curl -X DELETE ${API_BASE}/admin/users/${TEST_USER_ID} \\"
  echo "  -H 'Authorization: Bearer \$TOKEN'"
  echo ""

  read -p "Press Enter to execute..."

  DELETE_SUCCESS=$(curl -s -X DELETE "${API_BASE}/admin/users/${TEST_USER_ID}" \
    -H "Authorization: Bearer ${TOKEN}")

  echo "Response:"
  echo "$DELETE_SUCCESS" | jq '.'
  echo ""
  echo "Expected: 200 OK with message 'User 'delete_test_user' deleted successfully'"
  echo ""

  # Verify deletion by trying to login
  echo "Verifying deletion by attempting to login as deleted user..."

  LOGIN_DELETED=$(curl -s -X POST "${API_BASE}/login" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "delete_test_user",
      "password": "password123"
    }')

  echo "Login attempt response:"
  echo "$LOGIN_DELETED" | jq '.'
  echo ""
  echo "Expected: Login should fail with 'invalid credentials' or 'user not found'"
fi

echo "=========================================="
echo ""
echo "Examples complete!"
echo ""
echo "Summary of tested scenarios:"
echo "1. Admin trying to delete self - BLOCKED (400)"
echo "2. Invalid user ID format - REJECTED (400)"
echo "3. Non-existent user - NOT FOUND (404)"
echo "4. Valid user deletion - SUCCESS (200)"
echo ""
echo "Additional scenarios to test manually:"
echo "- Non-admin user trying to delete (403 Forbidden)"
echo "- No authentication token (401 Unauthorized)"
echo "- Deleting the last admin user (400 Bad Request)"
echo ""
echo "For full test suite, run: ./test_delete_user.sh"
