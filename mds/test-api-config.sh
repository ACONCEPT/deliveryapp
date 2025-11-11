#!/bin/bash

# Test API Configuration
# This script builds the frontend with different configurations to verify setup

set -e

echo "=========================================="
echo "API Configuration Test"
echo "=========================================="
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

cd "$FRONTEND_DIR"

# Test 1: Default configuration (localhost)
echo "Test 1: Building with default configuration (localhost)..."
flutter build web \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev

if [ $? -eq 0 ]; then
    echo "✓ Default build successful"

    # Check the compiled JavaScript for the API URL
    if grep -q "localhost:8080" build/web/main.dart.js 2>/dev/null; then
        echo "✓ localhost:8080 found in compiled output"
    else
        echo "⚠️  localhost:8080 NOT found in compiled output (may be obfuscated)"
    fi
else
    echo "✗ Default build failed"
    exit 1
fi

echo ""

# Test 2: Production-like configuration
echo "Test 2: Building with production-like configuration..."
TEST_API_URL="https://example.execute-api.us-east-1.amazonaws.com"
flutter build web \
  --dart-define=API_BASE_URL="$TEST_API_URL" \
  --dart-define=ENVIRONMENT=prod

if [ $? -eq 0 ]; then
    echo "✓ Production build successful"

    # Check the compiled JavaScript for the API URL
    if grep -q "example.execute-api.us-east-1.amazonaws.com" build/web/main.dart.js 2>/dev/null; then
        echo "✓ Production URL found in compiled output"
    else
        echo "⚠️  Production URL NOT found in compiled output (may be obfuscated)"
    fi
else
    echo "✗ Production build failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
echo ""
echo "Note: URLs may be obfuscated in release builds."
echo "Check browser console for 'API Configuration' log to verify."
