#!/bin/bash

# Delivery App - Database Setup Script
# This script starts the PostgreSQL database and runs migrations

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Database Setup - Delivery App                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed"
    exit 1
fi

echo "📦 Starting PostgreSQL database..."
docker-compose up -d postgres

echo ""
echo "⏳ Waiting for database to be healthy..."
sleep 5

# Wait for database to be ready
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose ps postgres | grep -q "healthy"; then
        echo "✅ Database is healthy!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Database failed to become healthy"
    exit 1
fi

echo ""
echo "📊 Database Status:"
docker-compose ps postgres

echo ""
echo "🔧 Running migrations..."

# Check if Python CLI exists
if [ ! -f "$PROJECT_ROOT/tools/cli/cli.py" ]; then
    echo "❌ Migration CLI not found at tools/cli/cli.py"
    exit 1
fi

# Set database URL
export DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable"

# Check if venv exists, create if not
if [ ! -d "$PROJECT_ROOT/tools/cli/venv" ]; then
    echo "   Creating Python virtual environment..."
    cd "$PROJECT_ROOT/tools/cli"
    python3 -m venv venv
    source venv/bin/activate
    pip install -q -r requirements.txt
else
    cd "$PROJECT_ROOT/tools/cli"
    source venv/bin/activate
fi

# Run migrations
echo "   Running schema migration..."
python cli.py migrate

echo ""
echo "📝 Database Status:"
python cli.py status

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Database Setup Complete!                                         ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Database Connection:"
echo "  Host: localhost"
echo "  Port: 5433"
echo "  Database: delivery_app"
echo "  User: delivery_user"
echo "  Password: delivery_pass"
echo ""
echo "Connection String:"
echo "  postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                  JWT Configuration Check                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if .env exists
if [ -f "$PROJECT_ROOT/backend/.env" ]; then
    # Extract JWT_SECRET from .env
    JWT_SECRET=$(grep "^JWT_SECRET=" "$PROJECT_ROOT/backend/.env" | cut -d'=' -f2)
    JWT_LENGTH=${#JWT_SECRET}

    echo "✅ JWT_SECRET found in backend/.env"
    echo "   Length: $JWT_LENGTH characters"
    echo "   Preview: ${JWT_SECRET:0:8}..."

    if [ $JWT_LENGTH -lt 32 ]; then
        echo "⚠️  WARNING: JWT_SECRET should be at least 32 characters"
    fi
else
    echo "❌ backend/.env not found - JWT_SECRET not configured"
    echo "   Run: cp backend/.env.example backend/.env"
fi

echo ""
echo "Next Steps:"
echo "  1. Seed test data: cd tools/cli && source venv/bin/activate && python cli.py seed"
echo "  2. Start backend: ./tools/sh/start-backend.sh"
echo ""
