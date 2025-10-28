# Archived Migrations

These migrations have been **consolidated into schema.sql** (2025-10-27).
They are kept for historical reference only.

## Consolidated Migrations

All changes from these migration files are now included in `/backend/sql/schema.sql`:

1. **001_add_approval_system.sql** - Admin approval workflow for vendors and restaurants
2. **002_add_orders_system.sql** - Complete order management system from cart to delivery
3. **003_add_driver_assignment_constraints.sql** - Database-level safety constraints for driver assignment
4. **003_add_system_settings.sql** - System-wide configuration management
5. **004_add_hours_of_operation.sql** - Restaurant operating hours tracking
6. **add_vendor_to_menus.sql** - Menu ownership by vendors

## Do Not Use These Files

These migration files should **NOT** be run individually. Instead:

- For fresh database setup: Use `/backend/sql/schema.sql`
- For dropping all objects: Use `/backend/sql/drop_all.sql`
- For full reset: Run `./tools/sh/setup-database.sh`

## Historical Reference Only

These files are preserved for:
- Understanding the evolution of the database schema
- Reviewing the context of specific changes
- Auditing purposes
- Reference when creating future migrations
