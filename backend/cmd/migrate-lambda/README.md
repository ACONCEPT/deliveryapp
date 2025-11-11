# Migration Lambda Function

AWS Lambda function for running database migrations on RDS PostgreSQL.

## Overview

This Lambda function handles database migrations by embedding SQL schema files directly into the compiled binary. It supports multiple actions:

- `migrate`: Drop all tables and run fresh schema + seed data
- `status`: Check current database state (table count and list)
- `drop`: Drop all database objects
- `seed`: Seed initial test data (included in schema.sql)

## SQL Files - Source of Truth

**IMPORTANT**: The SQL files in this directory are **NOT** the source of truth.

- **Source of Truth**: `/backend/sql/schema.sql` and `/backend/sql/drop_all.sql`
- **Build Process**: The `build.sh` script automatically copies these files here during compilation
- **Cleanup**: Temporary copies are removed after the build completes

**Do not manually edit SQL files in this directory!** All changes should be made in `/backend/sql/`.

## How It Works

### 1. Go Embed Directive

The `embedded_sql.go` file uses Go's `//go:embed` directive to include SQL files in the binary:

```go
//go:embed schema.sql
var schemaSQL string

//go:embed drop_all.sql
var dropAllSQL string
```

This means the SQL is compiled into the binary at build time - no external files needed at runtime.

### 2. Build Process

When you run `./build.sh`, it:

1. **Copies** SQL files from `/backend/sql/` to this directory
2. **Compiles** the Go code (embedding the SQL files)
3. **Cleans up** the temporary SQL copies
4. **Packages** the binary as a Lambda deployment zip

### 3. Why This Approach?

Go's `//go:embed` directive has a limitation: it can only embed files in or below the package directory. It cannot use `../../` paths or follow symlinks.

Our solution:
- Maintain single source of truth in `/backend/sql/`
- Copy files during build (automated)
- Embed them into the binary
- Clean up after build

## Building

```bash
./build.sh
```

This produces:
- `../../build/migrate-bootstrap` - The compiled Lambda handler
- `../../build/migrate-lambda.zip` - Deployment package (12MB)

## Testing Locally

Requires AWS credentials and DATABASE_URL or SECRET_ARN environment variable:

```bash
# Set environment
export DATABASE_URL="postgres://user:pass@localhost:5432/dbname"

# Run locally
go run . '{"action":"status"}'
go run . '{"action":"migrate"}'
```

## Deployment

Deploy with Terraform:

```bash
cd ../../../terraform/infra
terraform apply
```

Invoke the deployed Lambda:

```bash
aws lambda invoke \
  --function-name delivery-app-migrate-dev \
  --payload '{"action":"status"}' \
  /tmp/response.json && cat /tmp/response.json
```

## Environment Variables

The Lambda function requires one of:

- `SECRET_ARN`: AWS Secrets Manager ARN containing database credentials (preferred)
- `DATABASE_URL`: PostgreSQL connection string (fallback)

## Actions

### migrate
Runs a complete database reset:
1. Drops all existing tables, types, and functions
2. Creates fresh schema from `schema.sql`
3. Seeds test users and data

### status
Returns database information:
- Number of tables
- List of all tables
- No destructive operations

### drop
Drops all database objects:
- All tables (CASCADE)
- All custom types (enums)
- All custom functions
- **WARNING**: Destructive operation!

### seed
Placeholder action - seed data is already included in `schema.sql`.

## File Structure

```
cmd/migrate-lambda/
├── README.md           # This file
├── build.sh           # Build script (copies SQL, compiles, packages)
├── embedded_sql.go    # Go embed directives
├── main.go           # Lambda handler logic
├── schema.sql        # (temporary, copied during build, git-ignored)
└── drop_all.sql      # (temporary, copied during build, git-ignored)
```

## Git Ignore

The temporary SQL files are automatically added to `.gitignore`:

```
backend/cmd/migrate-lambda/schema.sql
backend/cmd/migrate-lambda/drop_all.sql
```

Only the source files in `/backend/sql/` are tracked by git.
