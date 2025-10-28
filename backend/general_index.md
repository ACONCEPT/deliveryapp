# General Index - Backend Source Code Files
# 2-line summary of every source code file in backend

## FILE: main.go
Main application entry point that initializes database, configures routes, and starts the HTTP server.
Defines health check, public auth routes, protected user routes, and role-based admin/vendor/customer/driver routes.

## FILE: middleware.go
HTTP middleware functions for CORS, logging, and panic recovery.
Implements permissive CORS policy, request/response logging, and graceful panic handling for all endpoints.

## FILE: config/config.go
Configuration management that loads environment variables for database, server, and JWT settings.
Validates required fields (DATABASE_URL, JWT_SECRET) and provides defaults for optional settings.

## FILE: database/database.go
Database initialization and dependency injection container for all repositories.
Creates database connection, initializes all repository instances, and provides cleanup methods.

## FILE: models/user.go
Data models and request/response structs for users, customers, vendors, drivers, admins, and addresses.
Defines user types, status enums, authentication models, profile structures, and address management DTOs.

## FILE: models/restaurant.go
Data models for restaurants, vendor-restaurant relationships, and restaurant management requests.
Defines Restaurant, VendorRestaurant, RestaurantWithVendor structs and create/update request DTOs.

## FILE: repositories/common.go
Shared database query helper functions for all repositories.
Provides ExecuteStatement, GetData, SelectData, QueryRow, and Query abstractions over sqlx operations.

## FILE: repositories/user_repository.go
User and profile data access layer with authentication and CRUD operations.
Handles user creation with bcrypt hashing, credential validation, and profile management for all user types.

## FILE: repositories/customer_address_repository.go
Customer address data access layer with CRUD and default address management.
Supports creating, reading, updating, deleting addresses with transaction-based default address switching.

## FILE: repositories/restaurant_repository.go
Restaurant data access layer with CRUD operations and vendor-specific queries.
Provides methods to create, read, update, delete restaurants and fetch by vendor with join queries.

## FILE: repositories/vendor_restaurant_repository.go
Vendor-restaurant relationship data access layer for ownership management.
Handles linking vendors to restaurants, ownership transfers, and relationship queries.

## FILE: handlers/handler.go
Base handler struct and utility functions for JSON responses.
Provides Handler initialization, sendJSON, sendError, and sendSuccess helper methods.

## FILE: handlers/auth.go
Authentication handlers for login and signup with JWT token generation.
Implements user login with credential validation, signup with profile creation, and JWT token issuance.

## FILE: handlers/profile.go
User profile retrieval handler for authenticated users.
Fetches user details and type-specific profile data from database based on JWT claims.

## FILE: handlers/customer_address.go
Customer address management handlers with ownership validation and default address logic.
Implements create, read, update, delete, and set-default operations with customer ownership checks.

## FILE: handlers/restaurant.go
Restaurant CRUD handlers with role-based access control for vendors, customers, drivers, and admins.
Manages restaurant creation by vendors, updates/deletes with ownership verification, and filtered views per role.

## FILE: handlers/vendor_restaurant.go
Vendor-restaurant relationship handlers for admin oversight and ownership transfers.
Provides endpoints to view relationships, transfer restaurant ownership, and manage vendor-restaurant links.

## FILE: middleware/auth.go
JWT authentication middleware and role-based authorization guards.
Validates bearer tokens, extracts claims, adds user to context, and enforces user type requirements.

## FILE: middleware/auth_context.go
Context utilities for storing and retrieving authenticated user information.
Provides SetUserInContext, GetUserFromContext, and MustGetUserFromContext helper functions.

## FILE: sql/schema.sql
PostgreSQL database schema with tables, enums, indexes, triggers, and seed data.
Defines complete data model for users, profiles, restaurants, menus, addresses, and dashboard widgets.

## FILE: sql/drop_all.sql
Database cleanup script that drops all tables, types, and functions.
Removes all database objects in reverse dependency order for clean schema resets.
