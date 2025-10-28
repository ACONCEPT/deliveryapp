# Detailed Index - Tools, Scripts, and Shell Scripts
# Detailed summaries with class names, function signatures, and line numbers

================================================================================
FILE: tools/cli/cli.py
================================================================================
PURPOSE: Database migration CLI for managing PostgreSQL schema, migrations, seeding, and status.
LANGUAGE: Python 3
DEPENDENCIES: psycopg2, bcrypt

CLASS: DatabaseCLI (lines 16-266)
  Constructor: __init__(self, db_url=None) [line 17]
    - Initializes database connection with DATABASE_URL from env or parameter

  Method: connect(self) -> bool [line 25]
    - Establishes psycopg2 connection to PostgreSQL database

  Method: disconnect(self) [line 36]
    - Closes database cursor and connection

  Method: execute_sql_file(self, filepath) -> bool [line 44]
    - Reads and executes SQL from file path with transaction management

  Method: migrate(self, schema_path='backend/sql/schema.sql') -> bool [line 59]
    - Runs database migrations by executing drop_all.sql then schema.sql
    - Step 1: Drops all tables/objects if drop_all.sql exists
    - Step 2: Creates fresh schema from schema.sql

  Method: reset(self) -> bool [line 105]
    - Drops all tables and custom types from public schema
    - Queries pg_tables and pg_type to find objects to drop

  Method: status(self) -> bool [line 141]
    - Displays database version, tables with row counts and sizes
    - Lists custom enum types in the database

  Method: seed(self) -> bool [line 195]
    - Seeds database with test users (customer1, vendor1, driver1, admin1)
    - Hashes passwords with bcrypt, creates user and profile records
    - Creates corresponding profile entries (Customer, Vendor, Driver, Admin)

FUNCTION: main() [line 269]
  - Argument parser with commands: migrate, reset, status, seed
  - Accepts --db-url and --schema optional parameters
  - Entry point when executed as script

NOTABLE FEATURES:
  - Uses psycopg2 for PostgreSQL interaction
  - Bcrypt password hashing for secure test user creation
  - Transaction management with commit/rollback
  - Supports multiple user types: customer, vendor, driver, admin
  - Profile table auto-creation based on user_type


================================================================================
FILE: tools/scripts/generate_password_hashes.py
================================================================================
PURPOSE: Generate bcrypt password hashes for test users to update schema.sql INSERT statements.
LANGUAGE: Python 3
DEPENDENCIES: bcrypt

FUNCTION: generate_hash(password) -> str [line 9]
  - Takes password string as input
  - Returns bcrypt hash with auto-generated salt
  - Uses bcrypt.hashpw() and bcrypt.gensalt()

MAIN BLOCK: [lines 13-30]
  - Hardcoded password: 'password123'
  - User list: ['customer1', 'vendor1', 'driver1', 'admin1']
  - Generates unique hash for each user (different salts)
  - Outputs formatted for SQL INSERT statement
  - Prints instructions to copy hashes to schema.sql

NOTABLE FEATURES:
  - Each run generates different hashes due to random salts
  - Output format matches schema.sql INSERT syntax
  - Designed for development/testing purposes only


================================================================================
FILE: tools/sh/full-setup.sh
================================================================================
PURPOSE: Complete application setup orchestrator - database, seeding, and backend build.
LANGUAGE: Bash shell script
DEPENDENCIES: setup-database.sh, seed-database.sh, Go compiler

SCRIPT FLOW:
  Lines 13-18: Project root directory resolution
  Lines 20-26: Step 1/3 - Execute setup-database.sh
  Lines 28-34: Step 2/3 - Execute seed-database.sh
  Lines 36-59: Step 3/3 - Build Go backend
    - Check/create .env file from .env.example
    - Run 'go build -o delivery_app main.go middleware.go'
  Lines 61-91: Display success message and next steps
    - Shows connection info
    - Provides curl examples for API testing
    - Instructions for Docker and Flutter

NOTABLE FEATURES:
  - Uses 'set -e' for fail-fast behavior
  - Beautiful box-drawing characters for output
  - Comprehensive instructions in success message
  - Creates .env from template if missing


================================================================================
FILE: tools/sh/seed-database.sh
================================================================================
PURPOSE: Database seeding script that creates test user accounts via Python CLI.
LANGUAGE: Bash shell script
DEPENDENCIES: Python venv, cli.py

SCRIPT FLOW:
  Lines 13-16: Resolve project root and navigate to tools/cli
  Line 20: Set DATABASE_URL environment variable
  Lines 22-27: Verify Python venv exists
  Line 30: Activate virtual environment
  Line 35: Execute 'python cli.py seed'
  Lines 42-49: Display test account credentials

ENVIRONMENT VARIABLES:
  - DATABASE_URL: postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable

TEST ACCOUNTS CREATED:
  - customer1 / password123 (Customer)
  - vendor1   / password123 (Vendor)
  - driver1   / password123 (Driver)
  - admin1    / password123 (Admin)

NOTABLE FEATURES:
  - Requires venv from setup-database.sh
  - Uses bcrypt for secure password hashing
  - Warning: mentions plain passwords won't work with API


================================================================================
FILE: tools/sh/setup-database.sh
================================================================================
PURPOSE: Database initialization - starts PostgreSQL and runs schema migrations.
LANGUAGE: Bash shell script
DEPENDENCIES: docker-compose, Python 3, cli.py

SCRIPT FLOW:
  Lines 13-17: Resolve project root directory
  Lines 19-26: Start PostgreSQL container with docker-compose
  Lines 28-50: Wait for database health check (max 30 retries)
  Lines 52-54: Display database status
  Lines 56-78: Create Python venv and install requirements
  Lines 80-86: Run 'python cli.py migrate' and 'python cli.py status'
  Lines 88-106: Display success message and connection details

ENVIRONMENT VARIABLES:
  - DATABASE_URL: postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable

DATABASE CONFIGURATION:
  - Host: localhost
  - Port: 5433
  - Database: delivery_app
  - User: delivery_user
  - Password: delivery_pass

NOTABLE FEATURES:
  - Health check loop with visual progress
  - Auto-creates Python venv if missing
  - Runs migrations via cli.py (which now drops/recreates)
  - Provides next steps for seeding and starting backend


================================================================================
FILE: tools/sh/start-app.sh
================================================================================
PURPOSE: Minimal Flutter app launcher for quick development.
LANGUAGE: Bash shell script
DEPENDENCIES: Flutter SDK

SCRIPT FLOW:
  Line 6: Navigate to project root
  Line 9: Execute 'flutter run -d chrome' from frontend directory

NOTABLE FEATURES:
  - Simplest possible startup
  - No error checking or configuration
  - Direct launch in Chrome browser


================================================================================
FILE: tools/sh/start-backend.sh
================================================================================
PURPOSE: Backend server startup with environment configuration and build.
LANGUAGE: Bash shell script
DEPENDENCIES: Go compiler, .env file

SCRIPT FLOW:
  Lines 13-17: Resolve project root and navigate to backend
  Lines 19-35: Check/create .env file from .env.example
  Lines 37-41: Load environment variables from .env
  Lines 43-48: Set default environment values
  Lines 50-56: Display configuration
  Lines 58-70: Check Go installation and dependencies
  Lines 72-82: Build backend binary
  Lines 84-100: Start backend server with instructions

ENVIRONMENT VARIABLES:
  - DATABASE_URL: PostgreSQL connection string
  - SERVER_PORT: API server port (default: 8080)
  - JWT_SECRET: Secret key for JWT token signing
  - TOKEN_DURATION: JWT token expiration in hours (default: 72)
  - ENVIRONMENT: development/production mode

BUILD COMMAND:
  go build -o delivery_app main.go middleware.go

NOTABLE FEATURES:
  - Masks password in connection string display
  - Downloads Go dependencies if needed
  - Shows API endpoint URLs on startup
  - Runs with fail-fast (set -e)


================================================================================
FILE: tools/sh/start-flutter.sh
================================================================================
PURPOSE: Flutter web application launcher with dependency management.
LANGUAGE: Bash shell script
DEPENDENCIES: Flutter SDK, Chrome browser

SCRIPT FLOW:
  Lines 13-17: Resolve project root and navigate to frontend
  Lines 19-24: Check Flutter installation
  Line 27: Run 'flutter pub get' to install dependencies
  Lines 29-53: Display startup information and run app

FEATURES DISPLAYED:
  - Test account credentials
  - Backend URL requirement (http://localhost:8080)
  - Hot reload commands (r, R, q)

TEST ACCOUNTS:
  - testcustomer / password123 (Customer)
  - testvendor   / password123 (Vendor)
  - testdriver   / password123 (Driver)
  - testadmin    / password123 (Admin)

NOTABLE FEATURES:
  - Checks Flutter SDK availability
  - Installs dependencies before launch
  - Comprehensive hot reload instructions
  - Runs with fail-fast (set -e)


================================================================================
FILE: tools/sh/stop-all.sh
================================================================================
PURPOSE: Service shutdown script for all Docker and backend processes.
LANGUAGE: Bash shell script
DEPENDENCIES: docker-compose, pgrep, pkill

SCRIPT FLOW:
  Lines 13-17: Resolve project root directory
  Line 20: Execute 'docker-compose down'
  Lines 23-30: Find and kill backend processes
    - Uses pgrep to find 'delivery_app' processes
    - Uses pkill to terminate processes
    - Ignores errors with '|| true'

PROCESSES STOPPED:
  - All Docker containers (postgres, api)
  - Backend binary processes named 'delivery_app'

NOTABLE FEATURES:
  - Graceful shutdown with fail-fast disabled for process killing
  - Visual feedback for each shutdown step
  - Comprehensive cleanup of all services
