#!/bin/bash

# Run Frontend Locally
# This script runs the Flutter web app in development mode with explicit configuration

set -e

echo "=========================================="
echo "Starting Flutter Frontend (Development)"
echo "=========================================="
echo ""

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Check if backend is running
echo "Checking if backend is running on localhost:8080..."
if curl -s -f -o /dev/null http://localhost:8080/health 2>/dev/null; then
    echo "✓ Backend is running"
else
    echo "⚠️  Warning: Backend not detected on localhost:8080"
    echo "   Make sure to start the backend server first:"
    echo ""
    echo "   cd backend && go run main.go"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Starting Flutter web server..."
echo "Backend API: http://localhost:8080"
echo "Frontend will be available at: http://localhost:PORT"
echo ""

cd "$FRONTEND_DIR"

# Run with development configuration (defaults to localhost:8080)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev
