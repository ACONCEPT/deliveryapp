#!/bin/bash

# Run Local Frontend Script
# This script runs the Flutter web app with local backend configuration

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Local Frontend Development${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get the project root directory (3 levels up from tools/sh/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Default local backend URL
DEFAULT_BACKEND_URL="http://localhost:8080"
BACKEND_URL="${1:-$DEFAULT_BACKEND_URL}"

echo -e "${YELLOW}Starting Flutter web app with local backend configuration${NC}"
echo "Backend URL: $BACKEND_URL"
echo ""

cd "$FRONTEND_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Note: The backend URL defaults to http://localhost:8080${NC}"
echo -e "${GREEN}You can override by passing a URL: $0 http://localhost:3000${NC}"
echo ""

# Run Flutter with local backend configuration
# Note: --dart-define is optional here since ApiConfig.dart defaults to localhost:8080
# But we pass it explicitly for clarity and to allow customization
if [ "$BACKEND_URL" != "$DEFAULT_BACKEND_URL" ]; then
    echo -e "${YELLOW}Running with custom backend: $BACKEND_URL${NC}"
    flutter run -d chrome --dart-define=API_BASE_URL="$BACKEND_URL"
else
    echo -e "${YELLOW}Running with default backend: $DEFAULT_BACKEND_URL${NC}"
    flutter run -d chrome
fi
