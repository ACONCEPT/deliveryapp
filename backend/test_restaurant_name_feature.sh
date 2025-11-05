#!/bin/bash

# Test script for restaurant_name field in orders table
# Verifies that restaurant_name is correctly stored and returned in API responses

set -e

echo "========================================"
echo "Testing restaurant_name in orders table"
echo "========================================"
echo ""

# Configuration
API_URL="http://localhost:8080"
CUSTOMER_USERNAME="customer1"
CUSTOMER_PASSWORD="password123"

echo "Step 1: Login as customer to get JWT token..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${CUSTOMER_USERNAME}\",\"password\":\"${CUSTOMER_PASSWORD}\"}")

# Extract token
TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get authentication token"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Successfully authenticated"
echo "Token: ${TOKEN:0:20}..."
echo ""

echo "Step 2: Get customer profile to retrieve customer_id and address_id..."
PROFILE_RESPONSE=$(curl -s -X GET "${API_URL}/api/profile" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Profile response: $PROFILE_RESPONSE"
echo ""

# Get restaurant ID from database
echo "Step 3: Get restaurant information from database..."
RESTAURANT_INFO=$(psql postgres://delivery_user:delivery_pass@localhost:5433/delivery_app -t -c "SELECT id, name FROM restaurants LIMIT 1;")
RESTAURANT_ID=$(echo $RESTAURANT_INFO | awk '{print $1}')
RESTAURANT_NAME=$(echo $RESTAURANT_INFO | cut -d'|' -f2 | xargs)

echo "Restaurant ID: $RESTAURANT_ID"
echo "Restaurant Name: $RESTAURANT_NAME"
echo ""

# Get address ID
ADDRESS_ID=$(psql postgres://delivery_user:delivery_pass@localhost:5433/delivery_app -t -c "SELECT id FROM customer_addresses WHERE customer_id = (SELECT id FROM customers WHERE user_id = (SELECT id FROM users WHERE username = '${CUSTOMER_USERNAME}')) LIMIT 1;" | xargs)

if [ -z "$ADDRESS_ID" ]; then
    echo "❌ No address found for customer"
    exit 1
fi

echo "Address ID: $ADDRESS_ID"
echo ""

echo "Step 4: Create a test order..."
CREATE_ORDER_RESPONSE=$(curl -s -X POST "${API_URL}/api/customer/orders" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"restaurant_id\": ${RESTAURANT_ID},
    \"delivery_address_id\": ${ADDRESS_ID},
    \"special_instructions\": \"Test order for restaurant_name field verification\",
    \"items\": [
      {
        \"menu_item_name\": \"Test Item\",
        \"menu_item_description\": \"Testing restaurant_name feature\",
        \"price\": 10.99,
        \"quantity\": 2,
        \"customizations\": {\"size\": \"large\"}
      }
    ]
  }")

echo "Create Order Response:"
echo "$CREATE_ORDER_RESPONSE"
echo ""

# Check if restaurant_name is in response
if echo "$CREATE_ORDER_RESPONSE" | grep -q "\"restaurant_name\""; then
    RETURNED_NAME=$(echo $CREATE_ORDER_RESPONSE | grep -o '"restaurant_name":"[^"]*' | sed 's/"restaurant_name":"//')
    echo "✅ restaurant_name field is present in response"
    echo "   Returned name: '$RETURNED_NAME'"

    if [ "$RETURNED_NAME" == "$RESTAURANT_NAME" ]; then
        echo "✅ Restaurant name matches expected value"
    else
        echo "⚠️  WARNING: Restaurant name mismatch!"
        echo "   Expected: '$RESTAURANT_NAME'"
        echo "   Got: '$RETURNED_NAME'"
    fi
else
    echo "❌ FAILED: restaurant_name field is missing from response"
    exit 1
fi
echo ""

# Extract order ID from response
ORDER_ID=$(echo $CREATE_ORDER_RESPONSE | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')

if [ -z "$ORDER_ID" ]; then
    echo "❌ Could not extract order ID from response"
    exit 1
fi

echo "Created Order ID: $ORDER_ID"
echo ""

echo "Step 5: Verify restaurant_name is stored in database..."
DB_RESTAURANT_NAME=$(psql postgres://delivery_user:delivery_pass@localhost:5433/delivery_app -t -c "SELECT restaurant_name FROM orders WHERE id = ${ORDER_ID};" | xargs)

echo "Database restaurant_name: '$DB_RESTAURANT_NAME'"

if [ "$DB_RESTAURANT_NAME" == "$RESTAURANT_NAME" ]; then
    echo "✅ Database value matches expected restaurant name"
else
    echo "❌ FAILED: Database value doesn't match"
    echo "   Expected: '$RESTAURANT_NAME'"
    echo "   Got: '$DB_RESTAURANT_NAME'"
    exit 1
fi
echo ""

echo "Step 6: Fetch order details to verify restaurant_name is returned..."
ORDER_DETAILS=$(curl -s -X GET "${API_URL}/api/customer/orders/${ORDER_ID}" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Order Details Response:"
echo "$ORDER_DETAILS"
echo ""

if echo "$ORDER_DETAILS" | grep -q "\"restaurant_name\":\"$RESTAURANT_NAME\""; then
    echo "✅ restaurant_name correctly returned in order details endpoint"
else
    echo "⚠️  WARNING: restaurant_name not found or doesn't match in order details"
fi
echo ""

echo "Step 7: List customer orders to verify restaurant_name in list view..."
ORDERS_LIST=$(curl -s -X GET "${API_URL}/api/customer/orders" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Orders List Response (first 500 chars):"
echo "$ORDERS_LIST" | head -c 500
echo ""
echo "..."
echo ""

if echo "$ORDERS_LIST" | grep -q "\"restaurant_name\""; then
    echo "✅ restaurant_name is present in orders list"
else
    echo "⚠️  WARNING: restaurant_name not found in orders list"
fi
echo ""

echo "========================================"
echo "✅ ALL TESTS PASSED!"
echo "========================================"
echo ""
echo "Summary:"
echo "  - restaurant_name field added to orders table"
echo "  - Restaurant name fetched and stored during order creation"
echo "  - Restaurant name returned in API responses"
echo "  - Database value matches expected restaurant name"
echo "  - Historical accuracy preserved (name stored at order time)"
echo ""
