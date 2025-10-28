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

# Code Style Preferences

prefer a pure, abstract, object oriented method wherever possible.

keep the code as DRY as possible. look for repeated code patterns and find ways to abstract these into reusable logic.

maintain clean abstraction layers with well-reasoned separation of concerns.
