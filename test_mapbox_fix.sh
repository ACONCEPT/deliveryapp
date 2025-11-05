#!/bin/bash
# Test script to verify Mapbox token is working in Docker

set -e

echo "========================================="
echo "Testing Mapbox Token in Docker Container"
echo "========================================="
echo ""

# Navigate to project root
cd "$(dirname "$0")"

echo "Step 1: Stopping existing containers..."
docker-compose down
echo ""

echo "Step 2: Rebuilding and starting containers..."
docker-compose up --build -d
echo ""

echo "Step 3: Waiting for backend to be ready (10 seconds)..."
sleep 10
echo ""

echo "Step 4: Checking backend logs for Mapbox warning..."
echo "----------------------------------------"
if docker logs delivery_app_api 2>&1 | grep -q "MAPBOX_ACCESS_TOKEN is not set"; then
    echo "❌ FAILED: Mapbox token warning still present"
    echo ""
    echo "Full backend logs:"
    docker logs delivery_app_api
    exit 1
else
    echo "✅ SUCCESS: No Mapbox token warning found"
fi
echo ""

echo "Step 5: Testing distance API endpoint..."
echo "----------------------------------------"
RESPONSE=$(curl -s -X POST http://localhost:8080/api/distance/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 34.0522, "longitude": -118.2437},
    "destination": {"latitude": 34.0407, "longitude": -118.2468}
  }')

echo "Response: $RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ SUCCESS: Distance API is working!"
    echo ""
    echo "Distance: $(echo $RESPONSE | grep -o '"distance_miles":[0-9.]*' | cut -d: -f2) miles"
    echo "Duration: $(echo $RESPONSE | grep -o '"duration_minutes":[0-9]*' | cut -d: -f2) minutes"
else
    echo "❌ FAILED: Distance API returned an error"
    exit 1
fi
echo ""

echo "========================================="
echo "All tests passed! Mapbox token is working correctly."
echo "========================================="
echo ""
echo "To view live logs: docker logs -f delivery_app_api"
echo "To stop containers: docker-compose down"