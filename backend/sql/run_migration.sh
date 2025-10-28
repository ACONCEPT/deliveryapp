#!/bin/bash

# Migration Runner Script
# Applies a migration file to the delivery_app database

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Database connection details
DB_NAME="delivery_app"
DB_USER="delivery_user"
DB_PASSWORD="delivery_pass"
DB_HOST="localhost"
DB_PORT="5433"

# Parse command line arguments
MIGRATION_FILE=$1

if [ -z "$MIGRATION_FILE" ]; then
    echo -e "${RED}Error: No migration file specified${NC}"
    echo "Usage: $0 <migration_file>"
    echo "Example: $0 migrations/001_add_approval_system.sql"
    exit 1
fi

# Check if migration file exists
if [ ! -f "$MIGRATION_FILE" ]; then
    echo -e "${RED}Error: Migration file not found: $MIGRATION_FILE${NC}"
    exit 1
fi

# Display migration info
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  Migration Runner${NC}"
echo -e "${YELLOW}================================================${NC}"
echo -e "Database: ${GREEN}$DB_NAME${NC}"
echo -e "Host:     ${GREEN}$DB_HOST:$DB_PORT${NC}"
echo -e "File:     ${GREEN}$MIGRATION_FILE${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""

# Confirm before running
read -p "Run this migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Migration cancelled${NC}"
    exit 0
fi

# Run migration
echo -e "${YELLOW}Running migration...${NC}"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$MIGRATION_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Migration completed successfully${NC}"
else
    echo -e "${RED}✗ Migration failed${NC}"
    exit 1
fi