#!/bin/bash

# Delivery App - Full Setup Script
# This script sets up the entire application (database + backend + test data)

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Full Application Setup - Delivery App                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📍 Project Root: $PROJECT_ROOT"
echo ""

# Step 1: Setup Database
echo "════════════════════════════════════════════════════════════════════════"
echo "Step 1/3: Setting up database..."
echo "════════════════════════════════════════════════════════════════════════"
echo ""

bash "$SCRIPT_DIR/setup-database.sh"

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "Step 2/3: Seeding test data..."
echo "════════════════════════════════════════════════════════════════════════"
echo ""

bash "$SCRIPT_DIR/seed-database.sh"

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "Step 3/3: Building backend..."
echo "════════════════════════════════════════════════════════════════════════"
echo ""

cd "$PROJECT_ROOT/backend"

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
fi

# Build backend
echo "Building backend binary..."
go build -o delivery_app main.go middleware.go

if [ $? -eq 0 ]; then
    echo "✅ Backend built successfully!"
else
    echo "❌ Backend build failed"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  🎉 Full Setup Complete!                                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Database: Running on port 5433"
echo "✅ Migrations: Applied"
echo "✅ Test Data: Seeded"
echo "✅ Backend: Built and ready"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Start the backend server:"
echo "   ./tools/sh/start-backend.sh"
echo ""
echo "2. Or start with Docker:"
echo "   docker-compose up -d"
echo ""
echo "3. Create test users via API:"
echo "   curl -X POST http://localhost:8080/api/signup \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"password123\",\"user_type\":\"customer\",\"full_name\":\"Test User\"}'"
echo ""
echo "4. Test login:"
echo "   curl -X POST http://localhost:8080/api/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"testuser\",\"password\":\"password123\"}'"
echo ""
echo "5. Run Flutter app:"
echo "   cd frontend && flutter run -d chrome"
echo ""
