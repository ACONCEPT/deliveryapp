#!/bin/bash

# AWS RDS Migration Script for Delivery App
# This script migrates the AWS RDS PostgreSQL database
# Usage: ./tools/sh/migrate-rds.sh [DATABASE_URL]

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         AWS RDS Database Migration - Delivery App                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Database URL (can be passed as argument or environment variable)
DB_URL="${1:-${DATABASE_URL}}"

# Default to the dev RDS instance if not provided
if [ -z "$DB_URL" ]; then
    DB_URL="postgres://delivery_user:delivery_pass@delivery-app-db-dev.cyt2u0ouqtpr.us-east-1.rds.amazonaws.com:5432/delivery_app?sslmode=require"
    echo "📝 Using default RDS URL"
fi

# Validate psql is installed
if ! command -v psql &> /dev/null; then
    echo "❌ psql is not installed"
    echo "   Install with: brew install postgresql"
    exit 1
fi

# Schema and drop files
SCHEMA_FILE="$PROJECT_ROOT/backend/sql/schema.sql"
DROP_FILE="$PROJECT_ROOT/backend/sql/drop_all.sql"

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ Schema file not found: $SCHEMA_FILE"
    exit 1
fi

if [ ! -f "$DROP_FILE" ]; then
    echo "❌ Drop file not found: $DROP_FILE"
    exit 1
fi

echo "📊 Database Configuration:"
echo "   URL: ${DB_URL%%@*}@***"
echo "   Schema: $SCHEMA_FILE"
echo "   Drop Script: $DROP_FILE"
echo ""

# Test database connectivity
echo "🔌 Testing database connectivity..."
if ! timeout 10 psql "$DB_URL" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Cannot connect to database"
    echo ""
    echo "Possible issues:"
    echo "  1. Security Group: Ensure port 5432 is open from your IP"
    echo "  2. Network: Check VPN or network connectivity to AWS"
    echo "  3. Credentials: Verify username/password are correct"
    echo "  4. SSL: Connection requires sslmode=require for RDS"
    echo ""
    echo "To check security groups:"
    echo "  aws rds describe-db-instances --db-instance-identifier delivery-app-db-dev"
    echo ""
    exit 1
fi

echo "✅ Successfully connected to database"
echo ""

# Show current database state
echo "📋 Current Database State:"
TABLE_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | xargs)
echo "   Tables: $TABLE_COUNT"

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo ""
    echo "📊 Existing Tables:"
    psql "$DB_URL" -c "\dt" 2>/dev/null | head -30
    echo ""
fi

# Ask for confirmation before proceeding
echo "⚠️  WARNING: This will DROP ALL existing tables and data!"
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Migration cancelled"
    exit 1
fi

echo ""
echo "🗑️  Dropping all existing database objects..."

# Run drop_all.sql
if psql "$DB_URL" -f "$DROP_FILE" > /dev/null 2>&1; then
    echo "✅ Successfully dropped all objects"
else
    echo "⚠️  Warning: Some objects may not have been dropped (might be first run)"
fi

echo ""
echo "🔧 Running schema migration..."

# Run schema.sql
if psql "$DB_URL" -f "$SCHEMA_FILE" > /tmp/migration_output.txt 2>&1; then
    echo "✅ Schema migration completed successfully"
else
    echo "❌ Schema migration failed"
    echo ""
    echo "Error output:"
    cat /tmp/migration_output.txt
    exit 1
fi

echo ""
echo "📊 Verifying migration..."

# Count tables after migration
NEW_TABLE_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | xargs)

echo "   Tables created: $NEW_TABLE_COUNT"

# Show table list
echo ""
echo "📋 Database Tables:"
psql "$DB_URL" -c "\dt" 2>/dev/null

echo ""
echo "📊 Table Row Counts:"
psql "$DB_URL" << 'EOF'
SELECT
    schemaname,
    tablename,
    (SELECT COUNT(*) FROM pg_catalog.pg_class WHERE relname = tablename) as row_count
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ AWS RDS Migration Complete!                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Database State:"
echo "  Tables: $NEW_TABLE_COUNT"
echo "  Seed Data: Test users and sample restaurants created"
echo ""
echo "Test Credentials (from schema.sql):"
echo "  customer1 / password123 (Customer)"
echo "  vendor1 / password123 (Vendor)"
echo "  driver1 / password123 (Driver)"
echo "  admin1 / password123 (Admin)"
echo ""
echo "Next Steps:"
echo "  1. Test API connection to RDS"
echo "  2. Update backend/.env with DATABASE_URL"
echo "  3. Deploy backend with new database"
echo ""
echo "Connection String (for backend/.env):"
echo "DATABASE_URL=\"$DB_URL\""
echo ""
