#!/bin/bash

# Quick AWS RDS Migration Script (No Prompts)
# This script migrates without confirmation prompts - USE WITH CAUTION
# Usage: ./tools/sh/quick-migrate-rds.sh [DATABASE_URL]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Database URL
DB_URL="${1:-${DATABASE_URL}}"

if [ -z "$DB_URL" ]; then
    DB_URL="postgres://delivery_user:delivery_pass@delivery-app-db-dev.cyt2u0ouqtpr.us-east-1.rds.amazonaws.com:5432/delivery_app?sslmode=require"
fi

SCHEMA_FILE="$PROJECT_ROOT/backend/sql/schema.sql"
DROP_FILE="$PROJECT_ROOT/backend/sql/drop_all.sql"

echo "🚀 Quick RDS Migration (No Confirmation)"
echo "   Database: ${DB_URL%%@*}@***"
echo ""

# Test connectivity
if ! timeout 10 psql "$DB_URL" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Cannot connect to database"
    exit 1
fi

echo "✅ Connected"
echo "🗑️  Dropping all objects..."
psql "$DB_URL" -f "$DROP_FILE" > /dev/null 2>&1 || true

echo "🔧 Running migration..."
if psql "$DB_URL" -f "$SCHEMA_FILE" > /dev/null 2>&1; then
    echo "✅ Migration complete"

    TABLE_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | xargs)
    echo "📊 Tables: $TABLE_COUNT"
else
    echo "❌ Migration failed"
    exit 1
fi
