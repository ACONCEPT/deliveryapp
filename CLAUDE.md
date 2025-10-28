# Scope

This file provides guidance on developing features for CLI use, or scripts that help manage the application frontend or backend runtime or deployment.
if you are developing a feature for the backend, reference ./backend/CLAUDE.md instead, if you are developing a front-end feature reference ./frontend/CLAUDE.md instead.

# Overview
Two index files are provided:

@./general_index.md
which contains a 2-line summary of every source code file in ./tools, ./scripts, and ./sh

and

@./detail_index.md
which contains a more detailed summary of each code file, including class names, signatures for constructors, methods, and functions, and corresponding
line numbers which indicate on which lines of the file these functions reside. 

if any api calling endpoints are experiencing issues, or if calling methods need to be updated or added, please reference ../backend/openapi.yaml
. . 
# Code review for implementation process

If you are attempting to plan implementation of a feature, looking for the cause of a bug, or actually implementing a feature, use the following algorithm in order to do so more effectively:

## Step 1: Search general_index.md for relevant files

Use grep to search for keywords and display the file path plus description:

```bash
# Find files related to database operations
grep -A 2 "database" general_index.md

# Find files related to seeding
grep -A 2 "seed" general_index.md

# Find files that handle backend startup
grep -A 2 "backend.*start" general_index.md

# Search for files by path pattern
grep "FILE: tools/cli" general_index.md
```

Example output:
```
## FILE: tools/cli/cli.py
Database migration CLI for managing PostgreSQL schema, migrations, seeding, and database status.
Provides commands: migrate, reset, status, seed with connection to delivery_app database.
```

## Step 2: Get detailed implementation from detail_index.md

Once you've identified relevant files, get detailed information including function signatures and line numbers:

```bash
# Get all details for a specific file
grep -A 100 "FILE: tools/cli/cli.py" detail_index.md | grep -B 100 "^===="

# Find specific class or function
grep -A 5 "CLASS: DatabaseCLI" detail_index.md

# Find function signatures with line numbers
grep "Method:" detail_index.md

# Search for specific functionality
grep -A 3 "migrate" detail_index.md | grep -E "(Method:|FUNCTION:)"

# Get environment variables used by a script
grep -A 10 "ENVIRONMENT VARIABLES:" detail_index.md

# Find dependencies for a file
grep "DEPENDENCIES:" detail_index.md
```

Example searches:

```bash
# Find all Python classes
grep "CLASS:" detail_index.md

# Find all shell script flows
grep "SCRIPT FLOW:" detail_index.md

# Get line numbers for a specific method
grep -A 2 "Method: migrate" detail_index.md
# Output: Method: migrate(self, schema_path='backend/sql/schema.sql') -> bool [line 59]
```

## Step 3: Review actual file and implement changes

Use the line numbers from detail_index.md to quickly navigate to the relevant code:

```bash
# View specific lines from a file
sed -n '59,103p' tools/cli/cli.py

# Or use your editor to jump to line
vim +59 tools/cli/cli.py
code -g tools/cli/cli.py:59
```

## Common Search Patterns

```bash
# Find which files handle a specific task
grep -i "password.*hash" general_index.md

# Get complete signature of all functions in a file
grep -A 1 "FUNCTION:" detail_index.md | grep -A 1 "tools/cli/cli.py"

# Find scripts that use docker
grep -i "docker" general_index.md

# Find all scripts with specific dependencies
grep "DEPENDENCIES:.*bcrypt" detail_index.md

# Search for specific line number ranges
grep "\[line [0-9]*\]" detail_index.md
```

# Code Style Preferences

prefer a pure, abstract, object oriented method wherever possible.

keep the code as DRY as possible. look for repeated code patterns and find ways to abstract these into reusable logic.

maintain clean abstraction layers with well-reasoned separation of concerns.
