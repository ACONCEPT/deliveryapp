#!/bin/bash

# Delivery App - Backend Start Script
# This script starts the Go API backend server

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Backend Server - Delivery App                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT/backend"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ Created .env file"
        echo ""
        echo "⚠️  IMPORTANT: Update the following in .env:"
        echo "   - JWT_SECRET (change to a secure random string)"
        echo "   - DATABASE_URL (verify it matches your setup)"
        echo ""
        read -p "Press Enter to continue or Ctrl+C to edit .env first..."
    else
        echo "❌ .env.example not found"
        exit 1
    fi
fi

# Load environment variables
if [ -f .env ]; then
    echo "📝 Loading environment variables from .env"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set default values if not in .env
export DATABASE_URL="${DATABASE_URL:-postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable}"
export SERVER_PORT="${SERVER_PORT:-8080}"
export JWT_SECRET="${JWT_SECRET:-change-this-secret-key-in-production}"
export TOKEN_DURATION="${TOKEN_DURATION:-72}"
export ENVIRONMENT="${ENVIRONMENT:-development}"

echo ""
echo "🔍 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   Server Port: $SERVER_PORT"
echo "   Database: $(echo $DATABASE_URL | sed 's/postgres:\/\/\([^:]*\):\([^@]*\)@/postgres:\/\/\1:***@/')"
echo "   Token Duration: ${TOKEN_DURATION}h"
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed"
    exit 1
fi

echo "📦 Checking Go dependencies..."
if [ ! -f go.sum ]; then
    echo "   Downloading dependencies..."
    go mod download
else
    echo "   ✅ Dependencies OK"
fi

echo ""
echo "🔧 Building backend..."
go build -o delivery_app main.go middleware.go

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful!"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  🚀 Starting Backend Server...                                       ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Server will be available at:"
echo "  • API: http://localhost:$SERVER_PORT"
echo "  • Health: http://localhost:$SERVER_PORT/health"
echo "  • Login: POST http://localhost:$SERVER_PORT/api/login"
echo "  • Signup: POST http://localhost:$SERVER_PORT/api/signup"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Run the backend
./delivery_app
