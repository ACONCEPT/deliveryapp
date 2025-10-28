# Scope

This file provides guidance on developing frontend features for the Flutter/Dart delivery application.
For backend development, reference ../backend/CLAUDE.md instead. For CLI/scripts development, reference ../CLAUDE.md instead.

# CRITICAL: Mandatory Index-Based Workflow

**IMPORTANT FOR ALL AGENTS AND DEVELOPMENT WORK:**

When working on ANY frontend task (planning, debugging, implementing, reviewing), you MUST follow this workflow:

1. **ALWAYS start with the indexes** - Never read source files directly without first consulting the indexes
2. **Search general_index.md FIRST** - Use grep to find relevant files by keyword
3. **Get details from detail_index.md SECOND** - Extract class names, method signatures, and line numbers
4. **Read source files LAST** - Only after identifying the exact files and line numbers needed

**WHY THIS MATTERS:**
- The frontend has 65+ files across models, services, screens, widgets, providers, utils, and config
- Reading files randomly wastes time and tokens
- The indexes provide a map to navigate the codebase efficiently
- Line numbers in detail_index.md allow precise navigation to relevant code

**THIS APPLIES TO:**
- ✅ Feature implementation
- ✅ Bug investigation
- ✅ Code review
- ✅ Refactoring
- ✅ Planning new features
- ✅ Understanding existing code
- ✅ ALL frontend development tasks

# Overview
Two index files are provided:

@./general_index.md
which contains a 2-line summary of every frontend source code file including main.dart, models, services, screens, widgets, config, and painters.

and

@./detail_index.md
which contains a more detailed summary of each code file, including class definitions, method signatures, constructors, factory methods, and corresponding
line numbers which indicate on which lines of the file these classes and methods reside.

# Correct vs Incorrect Workflows

## ❌ INCORRECT - Do NOT do this:
```
User: "Add a new field to the cart model"
Agent: *Immediately reads lib/models/cart.dart without checking indexes*
```

## ✅ CORRECT - Do this instead:
```
User: "Add a new field to the cart model"
Agent:
1. Searches general_index.md: grep "cart" frontend/general_index.md
2. Finds: "models/cart.dart - Shopping cart models with CartItem and Cart classes"
3. Gets details: grep -A 50 "FILE: models/cart.dart" frontend/detail_index.md
4. Sees Cart class at lines 96-194 with all fields and methods
5. NOW reads lib/models/cart.dart with line numbers 96-194 in mind
6. Makes informed changes
```

## ❌ INCORRECT - Do NOT do this:
```
User: "Fix the checkout flow"
Agent: *Randomly reads multiple screen files hoping to find checkout code*
```

## ✅ CORRECT - Do this instead:
```
User: "Fix the checkout flow"
Agent:
1. Searches general_index.md: grep -i "checkout" frontend/general_index.md
2. Finds: "screens/customer/checkout_screen.dart - Multi-step checkout flow"
3. Gets details: grep -A 80 "FILE: screens/customer/checkout_screen.dart" frontend/detail_index.md
4. Identifies CheckoutScreen class and relevant methods with line numbers
5. Reads the specific file with context
6. Fixes the issue efficiently
```

## Using Grep vs Bash Tool

**ALWAYS use Grep tool for searching index files:**
```bash
# ✅ CORRECT - Use Grep tool
grep "cart" frontend/general_index.md
grep -A 50 "CLASS: Cart" frontend/detail_index.md
```

**NEVER use Bash for searching indexes:**
```bash
# ❌ INCORRECT - Don't use Bash for index searches
bash: grep "cart" frontend/general_index.md
```

**Use Bash only for:**
- Running Flutter commands (flutter pub get, flutter run)
- Git operations
- Build/test commands
- File system operations (mkdir, mv, cp)

# Code review for implementation process

**MANDATORY ALGORITHM - Follow this for EVERY frontend task:**

If you are attempting to plan implementation of a feature, looking for the cause of a bug, or actually implementing a feature, use the following algorithm in order to do so more effectively:

## Step 1: Search general_index.md for relevant files

Use grep to search for keywords and display the file path plus description:

```bash
# Find files related to authentication
grep -A 2 "authentication" general_index.md

# Find files related to addresses
grep -A 2 "address" general_index.md

# Find files that handle restaurants
grep -A 2 "restaurant" general_index.md

# Search for files by directory pattern
grep "FILE: screens/" general_index.md

# Find service-related files
grep "FILE: services/" general_index.md

# Find widget files
grep "FILE: widgets/" general_index.md
```

Example output:
```
## FILE: services/api_service.dart
HTTP API service for authentication endpoints (login, signup) with comprehensive logging.
Handles POST requests to backend /api/login and /api/signup with error handling and response parsing.
```

## Step 2: Get detailed implementation from detail_index.md

Once you've identified relevant files, get detailed information including class definitions, method signatures, and line numbers:

```bash
# Get all details for a specific file
grep -A 100 "FILE: services/api_service.dart" detail_index.md | grep -B 100 "^===="

# Find specific class definitions
grep -A 5 "CLASS: User" detail_index.md

# Find all methods in a class
grep -A 30 "CLASS: AddressService" detail_index.md

# Search for specific method signatures
grep "Method:" detail_index.md

# Find screens with specific functionality
grep -A 3 "login\|signup" detail_index.md | grep -E "(CLASS:|Method:)"

# Get line numbers for a specific method
grep -A 2 "Method: build" detail_index.md
# Output: Method: build(BuildContext context) -> Widget [line 12]

# Find all StatefulWidget classes
grep "StatefulWidget" detail_index.md

# Find all factory constructors
grep "Factory:" detail_index.md

# Search for Flutter-specific code
grep -i "widget\|scaffold\|stateful" detail_index.md
```

Example searches:

```bash
# Find which files handle user models
grep -i "user.*model" general_index.md

# Get complete signature of all methods in a service
grep -A 1 "Method:" detail_index.md | grep -A 1 "services/api_service.dart"

# Find files that use HTTP requests
grep -i "http\|api" general_index.md

# Find all screen classes
grep "CLASS:.*Screen" detail_index.md

# Search for specific line number ranges
grep "\[line [0-9]*\]" detail_index.md

# Find configuration constants
grep "FILE: config/" general_index.md

# Find all async methods
grep "Future" detail_index.md | grep "Method:"

# Find JSON serialization methods
grep "fromJson\|toJson" detail_index.md
```

## Common Frontend Search Patterns

```bash
# Find authentication-related code
grep -i "auth\|login\|signup\|token" general_index.md

# Find API service methods
grep -A 50 "CLASS: ApiService" detail_index.md

# Get all screens
grep "FILE: screens/" general_index.md

# Find widget composition
grep "FILE: widgets/" general_index.md

# Search for stateful widgets
grep "StatefulWidget" detail_index.md

# Find data models
grep "FILE: models/" general_index.md

# Find form validation logic
grep -i "validat\|form" general_index.md

# Search for navigation code
grep -i "navigat\|route" detail_index.md

# Find state management
grep -i "state\|setstate" detail_index.md

# Get all constructors
grep "Constructor:" detail_index.md

# Find CRUD operations
grep "create\|update\|delete\|get" detail_index.md | grep "Method:"

# Search for UI constants
grep "FILE: config/dashboard_constants" detail_index.md

# Find custom painters
grep "CustomPainter" detail_index.md
```

## Step 3: Review actual file and implement changes

Use the line numbers from detail_index.md to quickly navigate to the relevant code:

```bash
# View specific lines from a file
sed -n '30,67p' services/api_service.dart

# Or use your editor to jump to line
vim +30 services/api_service.dart
code -g services/api_service.dart:30
```

# Code Style Preferences

prefer a pure, abstract, object oriented method wherever possible.

keep the code as DRY as possible. look for repeated code patterns and find ways to abstract these into reusable logic.

maintain clean abstraction layers with well-reasoned separation of concerns.

# Agent Responsibilities

When you are invoked as the **frontend-engineer** agent, you MUST:

1. **Start every task by consulting the indexes**
   - Use Grep to search general_index.md for relevant files
   - Use Grep to extract details from detail_index.md
   - Never skip this step, even for "simple" tasks

2. **Report what you found in the indexes**
   - Tell the user which files you identified
   - Mention the line numbers you found
   - This shows you're following the process

3. **Read only the files you identified**
   - Don't explore randomly
   - Use the line numbers to focus your reading
   - Read related files only if the indexes indicate they're needed

4. **Follow the 3-step algorithm:**
   ```
   STEP 1: grep keywords in general_index.md
   STEP 2: grep file details in detail_index.md
   STEP 3: Read source files with context
   ```

5. **Use the correct tools:**
   - Grep tool for searching indexes
   - Read tool for reading source files
   - Edit/Write tools for modifying code
   - Bash tool only for Flutter/git/build commands

## Example Agent Response Pattern

```
User: "Add a loading indicator to the cart screen"

Agent Response:
"I'll add a loading indicator to the cart screen. Let me first search the indexes to locate the relevant files.

[Uses Grep tool on general_index.md]
Found: screens/customer/cart_screen.dart - Shopping cart screen with item list and checkout navigation

[Uses Grep tool on detail_index.md]
Found CartScreen class at lines 15-250 with:
- _isLoading field at line 20
- build() method at line 45
- _loadCart() method at line 120

[Uses Read tool on lib/screens/customer/cart_screen.dart]
I can see the CartScreen is a StatefulWidget with state management. I'll add a loading indicator in the build method that displays when _isLoading is true.

[Makes changes using Edit tool]
Done! The loading indicator now appears while the cart is loading."
```

## Verification Checklist

Before completing any frontend task, verify:

- [ ] Did I search general_index.md first?
- [ ] Did I get details from detail_index.md second?
- [ ] Did I read source files last with line number context?
- [ ] Did I use Grep tool (not Bash) for index searches?
- [ ] Did I report my findings from the indexes?
- [ ] Did I follow the DRY and OOP style preferences?
- [ ] Did I maintain clean separation of concerns?

## Index Maintenance

If you discover files that are NOT in the indexes:

1. **Alert the user** that the indexes are incomplete
2. **Suggest updating** the indexes before proceeding
3. **Do not proceed** with implementation until indexes are complete
4. This ensures all future work benefits from complete documentation

The indexes are the foundation of efficient frontend development. Always use them!
