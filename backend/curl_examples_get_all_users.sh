#!/bin/bash

# Quick Reference: GET /api/admin/users Endpoint
# Prerequisite: Set ADMIN_TOKEN environment variable
# Example: export ADMIN_TOKEN="your-admin-jwt-token-here"

BASE_URL="http://localhost:8080/api"

# If ADMIN_TOKEN is not set, get it by logging in
if [ -z "$ADMIN_TOKEN" ]; then
  echo "Getting admin token..."
  LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/login" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "admin1",
      "password": "password123"
    }')

  ADMIN_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

  if [ -z "$ADMIN_TOKEN" ]; then
    echo "Failed to get admin token"
    exit 1
  fi

  echo "Admin token: $ADMIN_TOKEN"
  echo ""
fi

echo "========================================="
echo "GET /api/admin/users - Quick Examples"
echo "========================================="
echo ""

# Example 1: Get all users (default pagination)
echo "Example 1: Get all users"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  ${BASE_URL}/admin/users"
echo ""
echo "Response:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users" | jq '.'
echo ""
echo ""

# Example 2: Filter by user type (customers only)
echo "Example 2: Get all customers"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?user_type=customer\""
echo ""
echo "Response:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?user_type=customer" | jq '.data.users[] | {id, username, user_type, profile: .profile.full_name}'
echo ""
echo ""

# Example 3: Filter by user type (vendors only)
echo "Example 3: Get all vendors"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?user_type=vendor\""
echo ""
echo "Response:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?user_type=vendor" | jq '.data.users[] | {id, username, user_type, business_name: .profile.business_name, approval_status: .profile.approval_status}'
echo ""
echo ""

# Example 4: Filter by status
echo "Example 4: Get active users only"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?status=active\""
echo ""
echo "Response (summary):"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?status=active" | jq '{total_count: .data.total_count, users: [.data.users[] | {username, status}]}'
echo ""
echo ""

# Example 5: Search by name or email
echo "Example 5: Search for 'customer'"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?search=customer\""
echo ""
echo "Response (summary):"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?search=customer" | jq '{total_count: .data.total_count, users: [.data.users[] | {username, email}]}'
echo ""
echo ""

# Example 6: Pagination
echo "Example 6: Get page 1 with 2 users per page"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?page=1&per_page=2\""
echo ""
echo "Response (metadata):"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?page=1&per_page=2" | jq '{page: .data.page, per_page: .data.per_page, total_pages: .data.total_pages, total_count: .data.total_count, user_count: (.data.users | length)}'
echo ""
echo ""

# Example 7: Combined filters
echo "Example 7: Search for customers named 'customer'"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?user_type=customer&search=customer\""
echo ""
echo "Response:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?user_type=customer&search=customer" | jq '.data.users[] | {id, username, user_type, full_name: .profile.full_name}'
echo ""
echo ""

# Example 8: Get specific user types with pagination
echo "Example 8: Get first 10 vendors"
echo "Command:"
echo "curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "  \"${BASE_URL}/admin/users?user_type=vendor&per_page=10\""
echo ""
echo "Response (count only):"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "${BASE_URL}/admin/users?user_type=vendor&per_page=10" | jq '{total_vendors: .data.total_count, showing: (.data.users | length)}'
echo ""
echo ""

echo "========================================="
echo "All query parameters:"
echo "  user_type  : customer | vendor | driver | admin"
echo "  status     : active | inactive | suspended | pending | approved | rejected"
echo "  search     : any text (searches username, email, names)"
echo "  page       : page number (default: 1)"
echo "  per_page   : items per page (1-100, default: 20)"
echo "========================================="
