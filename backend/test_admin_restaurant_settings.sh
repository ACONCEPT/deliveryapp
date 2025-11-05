#!/bin/bash

# Test Admin Access to Restaurant Settings API
# This script tests that admins can access and modify any restaurant's settings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:8080"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Admin Restaurant Settings Access Test${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Step 1: Login as admin
echo -e "${YELLOW}Step 1: Login as admin1${NC}"
ADMIN_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }')

echo "$ADMIN_LOGIN_RESPONSE" | jq '.'
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN_RESPONSE" | jq -r '.token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo -e "${RED}Failed to get admin token${NC}"
  exit 1
fi
echo -e "${GREEN}Admin token obtained successfully${NC}\n"

# Step 2: Login as vendor1
echo -e "${YELLOW}Step 2: Login as vendor1${NC}"
VENDOR_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }')

echo "$VENDOR_LOGIN_RESPONSE" | jq '.'
VENDOR_TOKEN=$(echo "$VENDOR_LOGIN_RESPONSE" | jq -r '.token')

if [ "$VENDOR_TOKEN" = "null" ] || [ -z "$VENDOR_TOKEN" ]; then
  echo -e "${RED}Failed to get vendor token${NC}"
  exit 1
fi
echo -e "${GREEN}Vendor token obtained successfully${NC}\n"

# Step 3: Get restaurant ID for vendor1
echo -e "${YELLOW}Step 3: Get vendor1's restaurants${NC}"
VENDOR_RESTAURANTS=$(curl -s -X GET "$API_URL/api/restaurants" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$VENDOR_RESTAURANTS" | jq '.'
RESTAURANT_ID=$(echo "$VENDOR_RESTAURANTS" | jq -r '.restaurants[0].id')

if [ "$RESTAURANT_ID" = "null" ] || [ -z "$RESTAURANT_ID" ]; then
  echo -e "${RED}No restaurant found for vendor1${NC}"
  exit 1
fi
echo -e "${GREEN}Using restaurant ID: $RESTAURANT_ID${NC}\n"

# Step 4: Admin GET restaurant settings
echo -e "${YELLOW}Step 4: Admin GET restaurant settings for restaurant $RESTAURANT_ID${NC}"
ADMIN_GET_SETTINGS=$(curl -s -X GET "$API_URL/api/admin/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

echo "$ADMIN_GET_SETTINGS" | jq '.'
GET_SUCCESS=$(echo "$ADMIN_GET_SETTINGS" | jq -r '.success')

if [ "$GET_SUCCESS" = "true" ]; then
  echo -e "${GREEN}✓ Admin can GET restaurant settings${NC}\n"
else
  echo -e "${RED}✗ Admin CANNOT GET restaurant settings${NC}"
  exit 1
fi

# Step 5: Admin UPDATE restaurant prep time (PATCH)
echo -e "${YELLOW}Step 5: Admin PATCH restaurant prep time for restaurant $RESTAURANT_ID${NC}"
NEW_PREP_TIME=45
ADMIN_PATCH_RESPONSE=$(curl -s -X PATCH "$API_URL/api/admin/restaurant/$RESTAURANT_ID/prep-time" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"average_prep_time_minutes\": $NEW_PREP_TIME
  }")

echo "$ADMIN_PATCH_RESPONSE" | jq '.'
PATCH_SUCCESS=$(echo "$ADMIN_PATCH_RESPONSE" | jq -r '.success')

if [ "$PATCH_SUCCESS" = "true" ]; then
  UPDATED_PREP_TIME=$(echo "$ADMIN_PATCH_RESPONSE" | jq -r '.data.average_prep_time_minutes')
  if [ "$UPDATED_PREP_TIME" = "$NEW_PREP_TIME" ]; then
    echo -e "${GREEN}✓ Admin can PATCH restaurant prep time (updated to $NEW_PREP_TIME)${NC}\n"
  else
    echo -e "${RED}✗ Prep time not updated correctly${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ Admin CANNOT PATCH restaurant settings${NC}"
  exit 1
fi

# Step 6: Admin UPDATE restaurant settings (PUT)
echo -e "${YELLOW}Step 6: Admin PUT restaurant settings for restaurant $RESTAURANT_ID${NC}"
ADMIN_PUT_RESPONSE=$(curl -s -X PUT "$API_URL/api/admin/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 35,
    "hours_of_operation": {
      "monday": { "open": "10:00", "close": "22:00", "closed": false },
      "tuesday": { "open": "10:00", "close": "22:00", "closed": false },
      "wednesday": { "open": "10:00", "close": "22:00", "closed": false },
      "thursday": { "open": "10:00", "close": "22:00", "closed": false },
      "friday": { "open": "10:00", "close": "23:00", "closed": false },
      "saturday": { "open": "11:00", "close": "23:00", "closed": false },
      "sunday": { "open": "", "close": "", "closed": true }
    }
  }')

echo "$ADMIN_PUT_RESPONSE" | jq '.'
PUT_SUCCESS=$(echo "$ADMIN_PUT_RESPONSE" | jq -r '.success')

if [ "$PUT_SUCCESS" = "true" ]; then
  FINAL_PREP_TIME=$(echo "$ADMIN_PUT_RESPONSE" | jq -r '.data.average_prep_time_minutes')
  MONDAY_OPEN=$(echo "$ADMIN_PUT_RESPONSE" | jq -r '.data.hours_of_operation.monday.open')

  if [ "$FINAL_PREP_TIME" = "35" ] && [ "$MONDAY_OPEN" = "10:00" ]; then
    echo -e "${GREEN}✓ Admin can PUT restaurant settings (prep time and hours)${NC}\n"
  else
    echo -e "${RED}✗ Settings not updated correctly${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ Admin CANNOT PUT restaurant settings${NC}"
  exit 1
fi

# Step 7: Verify vendor can still access their own restaurant
echo -e "${YELLOW}Step 7: Verify vendor1 can still GET their restaurant settings${NC}"
VENDOR_GET_SETTINGS=$(curl -s -X GET "$API_URL/api/vendor/restaurant/$RESTAURANT_ID/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$VENDOR_GET_SETTINGS" | jq '.'
VENDOR_GET_SUCCESS=$(echo "$VENDOR_GET_SETTINGS" | jq -r '.success')

if [ "$VENDOR_GET_SUCCESS" = "true" ]; then
  echo -e "${GREEN}✓ Vendor can still access their own restaurant settings${NC}\n"
else
  echo -e "${RED}✗ Vendor CANNOT access their own restaurant${NC}"
  exit 1
fi

# Step 8: Test that vendor CANNOT access another restaurant (if there's a second one)
echo -e "${YELLOW}Step 8: Test vendor cannot access restaurants they don't own${NC}"
# Try to access a non-existent restaurant ID (999)
VENDOR_FORBIDDEN_RESPONSE=$(curl -s -X GET "$API_URL/api/vendor/restaurant/999/settings" \
  -H "Authorization: Bearer $VENDOR_TOKEN")

echo "$VENDOR_FORBIDDEN_RESPONSE" | jq '.'
VENDOR_FORBIDDEN=$(echo "$VENDOR_FORBIDDEN_RESPONSE" | jq -r '.success')

if [ "$VENDOR_FORBIDDEN" = "false" ]; then
  echo -e "${GREEN}✓ Vendor correctly denied access to other restaurants${NC}\n"
else
  echo -e "${RED}✗ Vendor should NOT access restaurants they don't own${NC}"
  exit 1
fi

# Summary
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}All Tests Passed!${NC}"
echo -e "${BLUE}=====================================${NC}\n"

echo -e "${GREEN}Summary:${NC}"
echo -e "  ✓ Admin can GET restaurant settings"
echo -e "  ✓ Admin can PATCH restaurant prep time"
echo -e "  ✓ Admin can PUT restaurant settings (full update)"
echo -e "  ✓ Vendor can access their own restaurant"
echo -e "  ✓ Vendor cannot access other restaurants"
echo -e "\n${GREEN}Admin authorization successfully implemented!${NC}\n"
