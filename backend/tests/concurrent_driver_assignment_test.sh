#!/bin/bash

# Concurrent Driver Assignment Test Script
# Tests race condition handling for driver self-assignment
#
# Prerequisites:
# - Backend server running on localhost:8080
# - Database populated with test data
# - Two driver accounts with valid JWT tokens
#
# Expected behavior:
# - Only ONE driver should successfully assign to each order
# - The second driver should receive a 409 Conflict response

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_URL="${API_URL:-http://localhost:8080}"
TEST_ORDER_ID="${TEST_ORDER_ID:-1}"

echo -e "${BLUE}=== Concurrent Driver Assignment Test ===${NC}\n"

# Check if tokens are provided
if [ -z "$DRIVER1_TOKEN" ] || [ -z "$DRIVER2_TOKEN" ]; then
    echo -e "${YELLOW}WARNING: Driver tokens not set${NC}"
    echo "Please set DRIVER1_TOKEN and DRIVER2_TOKEN environment variables"
    echo ""
    echo "Example:"
    echo "  export DRIVER1_TOKEN=\$(curl -s http://localhost:8080/api/login -H 'Content-Type: application/json' -d '{\"username\":\"driver1\",\"password\":\"password123\"}' | jq -r '.data.token')"
    echo "  export DRIVER2_TOKEN=\$(curl -s http://localhost:8080/api/login -H 'Content-Type: application/json' -d '{\"username\":\"driver2\",\"password\":\"password123\"}' | jq -r '.data.token')"
    echo ""

    # Try to get tokens automatically
    echo -e "${BLUE}Attempting to login as driver1 and driver2...${NC}"

    DRIVER1_RESPONSE=$(curl -s -X POST "$API_URL/api/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"driver1","password":"password123"}')

    DRIVER2_RESPONSE=$(curl -s -X POST "$API_URL/api/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"driver2","password":"password123"}')

    DRIVER1_TOKEN=$(echo "$DRIVER1_RESPONSE" | jq -r '.data.token // empty')
    DRIVER2_TOKEN=$(echo "$DRIVER2_RESPONSE" | jq -r '.data.token // empty')

    if [ -z "$DRIVER1_TOKEN" ] || [ -z "$DRIVER2_TOKEN" ]; then
        echo -e "${RED}ERROR: Failed to login. Please create driver1 and driver2 accounts.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Logged in successfully${NC}\n"
fi

# Function to assign order
assign_order() {
    local driver_num=$1
    local token=$2
    local order_id=$3
    local output_file="/tmp/driver${driver_num}_response.json"

    response=$(curl -s -w "\n%{http_code}" -X POST \
        "$API_URL/api/driver/orders/${order_id}/assign" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json")

    # Split response body and status code
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    echo "$body" > "$output_file"
    echo "$http_code" > "/tmp/driver${driver_num}_status.txt"

    echo "Driver $driver_num: HTTP $http_code"

    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}  ✓ Successfully assigned${NC}"
    elif [ "$http_code" = "409" ]; then
        echo -e "${YELLOW}  ⚠ Order already assigned (expected for second driver)${NC}"
        message=$(echo "$body" | jq -r '.message // .error // "Unknown error"')
        echo "    Message: $message"
    else
        echo -e "${RED}  ✗ Unexpected status code${NC}"
        echo "    Body: $body"
    fi
}

# Test 1: Sequential assignment (baseline)
echo -e "${BLUE}Test 1: Sequential Assignment (Baseline)${NC}"
echo "----------------------------------------------"
echo "Driver 1 assigns, then Driver 2 attempts to assign"
echo ""

assign_order 1 "$DRIVER1_TOKEN" "$TEST_ORDER_ID"
sleep 0.5  # Small delay to ensure first completes
assign_order 2 "$DRIVER2_TOKEN" "$TEST_ORDER_ID"

STATUS1=$(cat /tmp/driver1_status.txt)
STATUS2=$(cat /tmp/driver2_status.txt)

echo ""
if [ "$STATUS1" = "200" ] && [ "$STATUS2" = "409" ]; then
    echo -e "${GREEN}✓ Test 1 PASSED: First-come-first-serve working correctly${NC}"
else
    echo -e "${RED}✗ Test 1 FAILED: Expected Driver1=200, Driver2=409, got Driver1=$STATUS1, Driver2=$STATUS2${NC}"
fi

echo -e "\n"

# Create a fresh order for Test 2
# Note: This requires an admin or vendor to create an order in 'ready' status
# For now, we'll skip if order is already assigned

# Test 2: Concurrent assignment (race condition test)
echo -e "${BLUE}Test 2: Concurrent Assignment (Race Condition Test)${NC}"
echo "----------------------------------------------"
echo "Both drivers attempt to assign simultaneously"
echo ""

# You'll need to create a new order or reset the existing one
echo -e "${YELLOW}Note: You need to create a new order in 'ready' status for this test${NC}"
echo "Run this SQL to create a test order:"
echo ""
echo "UPDATE orders SET status = 'ready', driver_id = NULL WHERE id = $TEST_ORDER_ID;"
echo ""
echo -e "${YELLOW}Press Enter when ready to proceed with concurrent test, or Ctrl+C to exit${NC}"
read -r

# Reset temp files
rm -f /tmp/driver*_response.json /tmp/driver*_status.txt

# Launch both assignments in parallel
echo "Launching concurrent requests..."
assign_order 1 "$DRIVER1_TOKEN" "$TEST_ORDER_ID" &
PID1=$!
assign_order 2 "$DRIVER2_TOKEN" "$TEST_ORDER_ID" &
PID2=$!

# Wait for both to complete
wait $PID1
wait $PID2

echo ""

STATUS1=$(cat /tmp/driver1_status.txt 2>/dev/null || echo "ERROR")
STATUS2=$(cat /tmp/driver2_status.txt 2>/dev/null || echo "ERROR")

echo "Results:"
echo "  Driver 1: HTTP $STATUS1"
echo "  Driver 2: HTTP $STATUS2"
echo ""

# Validation
SUCCESS_COUNT=0
CONFLICT_COUNT=0

if [ "$STATUS1" = "200" ]; then
    ((SUCCESS_COUNT++))
fi
if [ "$STATUS2" = "200" ]; then
    ((SUCCESS_COUNT++))
fi
if [ "$STATUS1" = "409" ]; then
    ((CONFLICT_COUNT++))
fi
if [ "$STATUS2" = "409" ]; then
    ((CONFLICT_COUNT++))
fi

if [ "$SUCCESS_COUNT" = "1" ] && [ "$CONFLICT_COUNT" = "1" ]; then
    echo -e "${GREEN}✓ Test 2 PASSED: Exactly one driver assigned, race condition prevented!${NC}"
    echo "  One driver got 200 (success), the other got 409 (conflict)"
elif [ "$SUCCESS_COUNT" = "2" ]; then
    echo -e "${RED}✗ Test 2 FAILED: RACE CONDITION DETECTED!${NC}"
    echo -e "${RED}  Both drivers received 200 - this is a critical bug${NC}"
    echo "  The atomic check-and-set is not working properly"
elif [ "$SUCCESS_COUNT" = "0" ]; then
    echo -e "${YELLOW}⚠ Test 2 INCONCLUSIVE: Neither driver was assigned${NC}"
    echo "  This might mean the order wasn't in 'ready' status"
else
    echo -e "${YELLOW}⚠ Test 2 INCONCLUSIVE: Unexpected status codes${NC}"
fi

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""
echo "The fix is working correctly if:"
echo "  - Only ONE driver gets HTTP 200 (success)"
echo "  - The other driver gets HTTP 409 (conflict)"
echo "  - No matter how fast they both click, only one succeeds"
echo ""
echo "This proves the atomic UPDATE with WHERE conditions prevents race conditions."
echo ""

# Cleanup
rm -f /tmp/driver*_response.json /tmp/driver*_status.txt

echo -e "${BLUE}Test complete!${NC}"
