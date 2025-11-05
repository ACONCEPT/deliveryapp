# Scope

This file provides guidance on developing backend features for the delivery application API server.
For CLI/scripts development, reference ../CLAUDE.md instead. For frontend development, reference ../frontend/CLAUDE.md instead.

# Overview
Two index files are provided:

@./general_index.md
which contains a 2-line summary of every backend source code file including main.go, middleware, config, database, models, repositories, handlers, and SQL schema files.

and

@./detail_index.md
which contains a more detailed summary of each code file, including struct definitions, interface methods, function signatures, and corresponding
line numbers which indicate on which lines of the file these functions reside.

# Code review for implementation process

If you are attempting to plan implementation of a feature, looking for the cause of a bug, or actually implementing a feature, use the following algorithm in order to do so more effectively:

## Step 1: Search general_index.md for relevant files

Use grep to search for keywords and display the file path plus description:

```bash
# Find files related to authentication
grep -A 2 "authentication" general_index.md

# Find files related to restaurants
grep -A 2 "restaurant" general_index.md

# Find files that handle addresses
grep -A 2 "address" general_index.md

# Search for files by path pattern
grep "FILE: handlers/" general_index.md

# Find database-related files
grep "FILE: repositories/" general_index.md
```

Example output:
```
## FILE: handlers/auth.go
Authentication handlers for login and signup with JWT token generation.
Implements user login with credential validation, signup with profile creation, and JWT token issuance.
```

## Step 2: Get detailed implementation from detail_index.md

Once you've identified relevant files, get detailed information including function signatures and line numbers:

```bash
# Get all details for a specific file
grep -A 100 "FILE: handlers/auth.go" detail_index.md | grep -B 100 "^===="

# Find specific struct or interface
grep -A 5 "STRUCT: User" detail_index.md

# Find interface methods
grep -A 20 "INTERFACE: UserRepository" detail_index.md

# Search for specific method signatures
grep "METHOD:" detail_index.md

# Find handlers for specific operations
grep -A 3 "login\|signup" detail_index.md | grep -E "(METHOD:|FUNCTION:)"

# Get line numbers for a specific function
grep -A 2 "METHOD: Login" detail_index.md
# Output: METHOD: Login(w http.ResponseWriter, r *http.Request) [line 40]

# Find all repository interfaces
grep "INTERFACE:" detail_index.md

# Find all middleware functions
grep "FUNCTION:.*Middleware" detail_index.md

# Search for JWT-related code
grep -i "jwt" detail_index.md
```

Example searches:

```bash
# Find which files handle user creation
grep -i "create.*user" general_index.md

# Get complete signature of all methods in a file
grep -A 1 "METHOD:" detail_index.md | grep -A 1 "handlers/auth.go"

# Find files that use bcrypt
grep -i "bcrypt" detail_index.md

# Find all HTTP handlers
grep "METHOD:.*http.ResponseWriter" detail_index.md

# Search for specific line number ranges
grep "\[line [0-9]*\]" detail_index.md

# Find database table definitions
grep "CREATE TABLE" detail_index.md

# Find all repository factory functions
grep "FUNCTION: New.*Repository" detail_index.md
```

## Common Backend Search Patterns

```bash
# Find authentication-related code
grep -i "auth\|login\|signup\|token\|jwt" general_index.md

# Find repository methods for a specific model
grep -A 50 "INTERFACE: RestaurantRepository" detail_index.md

# Get all HTTP routes
grep "ROUTE CONFIGURATION:" -A 50 detail_index.md

# Find middleware configuration
grep "MIDDLEWARE STACK:" -A 10 detail_index.md

# Search for specific Go structs
grep "STRUCT:" detail_index.md | grep -i "request\|response"

# Find all database migrations
grep "FILE: sql/" general_index.md

# Find validation logic
grep -i "validat" general_index.md

# Search for error handling patterns
grep -i "error\|panic\|recover" general_index.md

# Find transaction handling
grep -i "transaction\|commit\|rollback" detail_index.md

# Get all enum/constant definitions
grep "TYPE:\|CONST:" detail_index.md

# Find CRUD operations
grep "Create\|GetBy\|Update\|Delete" detail_index.md | grep "METHOD:"
```

## Step 3: Review actual file and implement changes

Use the line numbers from detail_index.md to quickly navigate to the relevant code:

```bash
# View specific lines from a file
sed -n '40,86p' handlers/auth.go

# Or use your editor to jump to line
vim +40 handlers/auth.go
code -g handlers/auth.go:40
```

## step 4: Update documentation

prioritize updating ./backend/openapi.yaml any time changes are made to an endpoint input or response schema, behavior, auth requirements, or if new endpoints are added.

# Database Migration Management

## Current State (As of 2025-10-27)

The database schema has been **fully consolidated** into a single source of truth:

- **Main Schema**: `/backend/sql/schema.sql` (944 lines, 21 tables, 5 enums, 60+ indexes)
- **Drop Script**: `/backend/sql/drop_all.sql` (drops all objects for clean reset)
- **Archived Migrations**: `/backend/sql/migrations/archived/` (historical reference only)

All incremental migrations have been merged into `schema.sql`. The archived migrations are preserved for historical reference but should **NOT be executed**.

## Full Database Reset (Development)

For development and testing, always use the full reset approach:

```bash
# Method 1: Use the setup script (RECOMMENDED)
./tools/sh/setup-database.sh

# Method 2: Manual reset via CLI
cd tools/cli
source venv/bin/activate
python cli.py migrate  # Runs drop_all.sql + schema.sql
python cli.py status   # Verify tables created
```

The setup script will:
1. Start PostgreSQL in Docker (if not running)
2. Wait for database health check
3. Drop all existing objects (drop_all.sql)
4. Create fresh schema (schema.sql)
5. Seed 4 test users with bcrypt-hashed passwords
6. Seed 33 system settings
7. Display status with table counts

**Test Users Created**:
- customer1 / password123 (Customer)
- vendor1 / password123 (Vendor)
- driver1 / password123 (Driver)
- admin1 / password123 (Admin)

## Creating New Schema Changes

### Step 1: Determine Migration Type

**Development/Fresh Installs**: Update `schema.sql` directly
**Production/Data Preservation**: Create incremental migration file

### Step 2: For Development Changes (Direct Schema Update)

When adding features in development:

```bash
# 1. Edit schema.sql directly
vim backend/sql/schema.sql

# 2. Add your changes:
#    - New tables
#    - New columns (use ALTER TABLE syntax)
#    - New indexes
#    - New enums (remember to add to drop_all.sql too)
#    - New triggers/functions

# 3. Update drop_all.sql if needed
#    - Add DROP statements for new tables/types/functions
#    - Maintain reverse dependency order

# 4. Test the changes
./tools/sh/setup-database.sh

# 5. Verify schema
cd tools/cli && source venv/bin/activate && python cli.py status
```

### Step 3: For Production Changes (Incremental Migration)

When deploying to production with existing data:

```bash
# 1. Create new numbered migration file
touch backend/sql/migrations/00X_descriptive_name.sql

# Example: backend/sql/migrations/005_add_payment_methods.sql
```

**Migration File Template**:

```sql
-- Migration: Add payment methods table
-- Created: YYYY-MM-DD
-- Author: Your Name

-- Add new enum if needed
CREATE TYPE payment_method_type AS ENUM ('credit_card', 'debit_card', 'paypal', 'cash');

-- Create new table
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type payment_method_type NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes
CREATE INDEX idx_payment_methods_customer_id ON payment_methods(customer_id);
CREATE INDEX idx_payment_methods_default ON payment_methods(customer_id) WHERE is_default = true;

-- Add trigger for updated_at
CREATE TRIGGER update_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add column to existing table (if needed)
ALTER TABLE orders
ADD COLUMN payment_method_id INTEGER REFERENCES payment_methods(id);

-- Backward compatibility (set defaults for existing data)
-- Example: UPDATE existing_table SET new_column = 'default_value' WHERE new_column IS NULL;

-- Add comments
COMMENT ON TABLE payment_methods IS 'Customer payment methods for checkout';
```

**Apply Migration in Production**:

```bash
# Connect to production database
psql $DATABASE_URL -f backend/sql/migrations/005_add_payment_methods.sql

# Verify
psql $DATABASE_URL -c "\dt payment_methods"
```

### Step 4: Update Main Schema File

After creating and testing an incremental migration:

```bash
# 1. Apply the incremental migration changes to schema.sql
#    - Add new tables/enums/functions to schema.sql
#    - Maintain logical grouping (enums at top, tables by domain)
#    - Keep indexes in the indexes section

# 2. Update drop_all.sql
#    - Add DROP statements for new objects
#    - Maintain reverse dependency order

# 3. Test consolidated schema
./tools/sh/setup-database.sh

# 4. Archive the incremental migration (optional)
mv backend/sql/migrations/00X_*.sql backend/sql/migrations/archived/
```

## Type Casting Rules for Enums

**CRITICAL**: When using PostgreSQL enum types with parameterized queries, always use explicit type casting to avoid "inconsistent types deduced for parameter" errors.

**Example Issue**:
```sql
-- WRONG: Parameter $2 used in multiple type contexts
UPDATE orders SET
    status = $2,  -- enum type
    confirmed_at = CASE WHEN $2 = 'confirmed' THEN ... END  -- text comparison
WHERE id = $1;
```

**Solution**:
```sql
-- CORRECT: Explicit casting resolves ambiguity
UPDATE orders SET
    status = $2::order_status,
    confirmed_at = CASE WHEN $2::order_status = 'confirmed' THEN ... END
WHERE id = $1;
```

**Rule**: If a query parameter is:
1. Assigned to an enum column, AND
2. Compared with string literals elsewhere in the query

Then use `$N::enum_type_name` for ALL occurrences of that parameter.

## Schema Change Best Practices

### 1. Always Maintain Backward Compatibility in Production

```sql
-- GOOD: Add column with default
ALTER TABLE users ADD COLUMN phone_verified BOOLEAN DEFAULT false;

-- GOOD: Make nullable first, populate, then add NOT NULL
ALTER TABLE users ADD COLUMN email_verified BOOLEAN;
UPDATE users SET email_verified = false WHERE email_verified IS NULL;
ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;

-- BAD: Add NOT NULL column without default (breaks existing rows)
ALTER TABLE users ADD COLUMN required_field TEXT NOT NULL;
```

### 2. Use Transactions for Multi-Step Migrations

```sql
BEGIN;

-- Multiple related changes
ALTER TABLE restaurants ADD COLUMN rating_count INTEGER DEFAULT 0;
UPDATE restaurants SET rating_count = 0;
ALTER TABLE restaurants ALTER COLUMN rating_count SET NOT NULL;

COMMIT;
```

### 3. Create Indexes Concurrently in Production

```sql
-- Production: Non-blocking index creation
CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders(created_at);

-- Development: Regular index (faster)
CREATE INDEX idx_orders_created_at ON orders(created_at);
```

### 4. Handle Enum Changes Carefully

```sql
-- Adding enum value (PostgreSQL 12+)
ALTER TYPE order_status ADD VALUE 'refunded' AFTER 'cancelled';

-- Removing enum value requires type recreation (complex, avoid if possible)
-- Better: Keep deprecated values, add is_active flag
```

### 5. Always Update drop_all.sql

When adding new database objects:

```sql
-- schema.sql: Add new table
CREATE TABLE notifications (...);

-- drop_all.sql: Add corresponding drop
DROP TABLE IF EXISTS notifications CASCADE;
```

### 6. Test Migrations Both Ways

```bash
# Test fresh install
./tools/sh/setup-database.sh

# Test incremental migration
psql $DATABASE_URL -f backend/sql/migrations/00X_feature.sql

# Test rollback (if applicable)
psql $DATABASE_URL -f backend/sql/migrations/00X_feature_rollback.sql
```

## Migration Workflow Summary

**Development**:
1. Edit `schema.sql` directly
2. Update `drop_all.sql` if needed
3. Run `./tools/sh/setup-database.sh` to test
4. Commit changes

**Production Deployment**:
1. Create incremental migration file (`00X_feature.sql`)
2. Test migration on staging database
3. Apply to production: `psql $DATABASE_URL -f 00X_feature.sql`
4. Update `schema.sql` to include changes
5. Archive migration file
6. Commit all changes

**Emergency Rollback**:
1. Have rollback script ready before deploying
2. Test rollback on staging first
3. Apply rollback: `psql $DATABASE_URL -f 00X_feature_rollback.sql`

## Files You Must Update

When making schema changes:

- [ ] `/backend/sql/schema.sql` - Add new tables/columns/indexes
- [ ] `/backend/sql/drop_all.sql` - Add DROP statements for new objects
- [ ] `/backend/models/*.go` - Add Go structs for new tables
- [ ] `/backend/repositories/*.go` - Add repository methods for data access
- [ ] `/backend/handlers/*.go` - Add HTTP handlers if needed
- [ ] `/backend/openapi.yaml` - Document new endpoints/schemas
- [ ] `/backend/general_index.md` - Add 2-line summary (optional, for reference)
- [ ] `/backend/detail_index.md` - Add detailed signatures (optional, for reference)

## Critical Migration Rules

1. **NEVER drop user data without explicit backup**
2. **ALWAYS test migrations on a copy of production data**
3. **ALWAYS use transactions for multi-step changes**
4. **ALWAYS update both schema.sql and drop_all.sql**
5. **ALWAYS use explicit type casting for enum parameters**
6. **ALWAYS provide defaults or NULL for new columns on existing tables**
7. **ALWAYS create indexes CONCURRENTLY in production**
8. **NEVER run archived migrations from `/backend/sql/migrations/archived/`**

# Code Style Preferences

prefer a pure, abstract, object oriented method wherever possible.

keep the code as DRY as possible. look for repeated code patterns and find ways to abstract these into reusable logic.

maintain clean abstraction layers with well-reasoned separation of concerns.
