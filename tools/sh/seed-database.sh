#!/bin/bash

# Delivery App - Database Seeding Script
# This script seeds the database with test users

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Database Seeding - Delivery App                              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT/tools/cli"

# Set database URL
export DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found"
    echo "   Run ./tools/sh/setup-database.sh first"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

echo "🌱 Seeding database with test users..."
echo ""

python cli.py seed

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Database Seeding Complete!                                       ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Test accounts available:"
echo "  • customer1 / password123 (Customer)"
echo "  • vendor1   / password123 (Vendor)"
echo "  • driver1   / password123 (Driver)"
echo "  • admin1    / password123 (Admin)"
echo ""
echo "⚠️  Note: These accounts use plain passwords and won't work with the API."
echo "   Use the signup endpoint to create users with proper password hashing."
echo ""
