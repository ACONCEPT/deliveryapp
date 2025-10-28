# Database Maintenance Scripts

This directory contains SQL scripts for database maintenance and cleanup operations.

## Available Scripts

### 1. cleanup_orphaned_menus.sql

**Purpose:** Identifies and removes orphaned menus that have no restaurant associations.

**What are orphaned menus?**
Menus that exist in the `menus` table but have no entries in the `restaurant_menus` junction table. This can happen when:
- Menus are created but never assigned to restaurants
- All restaurant associations are deleted but the menu template remains
- Data inconsistencies during development/testing

**Usage:**

```bash
# Read-only mode: Identify orphaned menus without deleting
PGPASSWORD=delivery_pass psql -h localhost -p 5433 -U delivery_user -d delivery_app \
  -f backend/sql/scripts/cleanup_orphaned_menus.sql

# To execute deletion, uncomment the transaction block in the script
# and replace ROLLBACK with COMMIT
```

**Sections:**
1. **Identification (Read-Only):** Shows statistics and lists orphaned menus
2. **Cleanup (Commented):** Deletes orphaned menus in a transaction
3. **Verification:** Confirms cleanup was successful

### 2. execute_cleanup_orphaned_menus.sql

**Purpose:** Executes the orphaned menu deletion with automatic commit.

**Usage:**

```bash
PGPASSWORD=delivery_pass psql -h localhost -p 5433 -U delivery_user -d delivery_app \
  -f backend/sql/scripts/execute_cleanup_orphaned_menus.sql
```

**Safety Features:**
- Uses transactions (can be rolled back if needed)
- Displays what will be deleted before execution
- Shows verification after deletion
- Logs deleted menu details

## CLI Command Alternative

The Python CLI tool includes a built-in command for cleaning up orphaned menus:

```bash
# Navigate to CLI directory
cd tools/cli

# Activate Python virtual environment
source venv/bin/activate

# Dry-run mode (shows what would be deleted, makes no changes)
DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable" \
  python cli.py cleanup-orphaned-menus

# Execute mode (actually deletes orphaned menus)
DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable" \
  python cli.py cleanup-orphaned-menus --execute
```

**CLI Features:**
- Default dry-run mode for safety
- Interactive confirmation prompt
- Shows menu details before deletion
- Displays statistics after cleanup
- Built-in verification

## When to Run Cleanup

Consider running orphaned menu cleanup:
- After development/testing with temporary menus
- During database maintenance windows
- When menu counts don't match expected values
- After deleting test restaurants

## Database Schema Context

**Tables Involved:**
- `menus` - Menu template definitions with JSONB config
- `restaurant_menus` - Junction table linking restaurants to menus
- `vendors` - Menu ownership (menus.vendor_id)

**Key Relationships:**
```
menus (id) <-- restaurant_menus (menu_id) --> restaurants (id)
menus (vendor_id) --> vendors (id)
```

**Foreign Key Constraints:**
- `restaurant_menus.menu_id` REFERENCES `menus(id)` ON DELETE CASCADE
- `restaurant_menus.restaurant_id` REFERENCES `restaurants(id)` ON DELETE CASCADE
- `menus.vendor_id` REFERENCES `vendors(id)` ON DELETE CASCADE

This means:
- Deleting a menu automatically removes its restaurant_menus entries
- Deleting a restaurant automatically removes its restaurant_menus entries
- Orphaned menus occur when created but never linked to restaurants

## Safety Considerations

1. **Always review before deleting:** Run identification queries first
2. **Backup if necessary:** Consider pg_dump before bulk deletions
3. **Soft delete alternative:** Set `is_active = FALSE` instead of deleting
4. **Transaction safety:** Scripts use transactions for rollback capability
5. **Verify ownership:** Check vendor_id to ensure you're not deleting shared menus

## Example Output

### Identification Phase
```
total_menus | orphaned_menus | total_menu_assignments
-------------+----------------+------------------------
          11 |             10 |                      1

Found 10 orphaned menu(s):
  • ID:  12 | chinese                | Business vendor1     | Created: 2025-10-28
  • ID:  10 | Main Menu              | NO VENDOR            | Created: 2025-10-22
  ...
```

### After Cleanup
```
deleted_count | remaining_menus | remaining_assignments
--------------+-----------------+----------------------
           10 |               1 |                    1

✓ SUCCESS: All orphaned menus have been removed
```

## Troubleshooting

**No orphaned menus found:**
- Database is clean, no action needed

**Orphaned menus still exist after cleanup:**
- Check for transaction rollback
- Verify foreign key constraints
- Check for concurrent menu creation

**Permission errors:**
- Ensure database user has DELETE privileges on menus table
- Verify connection credentials

## Related Documentation

- Database Schema: `backend/sql/schema.sql`
- CLI Tool: `tools/cli/cli.py`
- General Index: `backend/general_index.md`
- Detail Index: `backend/detail_index.md`
