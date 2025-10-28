# General Index - Tools, Scripts, and Shell Scripts
# 2-line summary of every source code file in ./tools

## FILE: tools/cli/cli.py
Database migration CLI for managing PostgreSQL schema, migrations, seeding, and database status.
Provides commands: migrate, reset, status, seed with connection to delivery_app database.

## FILE: tools/scripts/generate_password_hashes.py
Utility script for generating bcrypt password hashes for test users in schema.sql.
Outputs formatted INSERT statements with hashed passwords for customer1, vendor1, driver1, admin1.

## FILE: tools/sh/full-setup.sh
Complete application setup orchestrator that runs database setup, seeding, and backend build.
Executes setup-database.sh, seed-database.sh, and builds the Go backend binary in sequence.

## FILE: tools/sh/seed-database.sh
Database seeding script that populates test user accounts using the Python CLI tool.
Activates Python venv and runs 'cli.py seed' to create test users for all user types.

## FILE: tools/sh/setup-database.sh
Database initialization script that starts PostgreSQL container and runs schema migrations.
Creates Python venv, installs dependencies, and executes migration via cli.py migrate command.

## FILE: tools/sh/start-app.sh
Minimal launcher that starts the Flutter web application in Chrome browser.
Simply changes to frontend directory and runs 'flutter run -d chrome'.

## FILE: tools/sh/start-backend.sh
Backend server startup script with environment configuration and dependency checking.
Loads .env, checks Go installation, builds backend binary, and starts the API server.

## FILE: tools/sh/start-flutter.sh
Flutter web application launcher with dependency installation and configuration display.
Runs 'flutter pub get' and launches app in Chrome with hot reload instructions.

## FILE: tools/sh/stop-all.sh
Service shutdown script that stops all Docker containers and backend processes.
Executes 'docker-compose down' and kills any running delivery_app backend processes.
