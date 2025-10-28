-- Drop All Tables and Objects Script
-- PostgreSQL script to completely clean the delivery_app database
-- CAUTION: This will delete ALL data permanently!
-- Last Updated: 2025-10-27 (includes all migration tables)

-- ============================================================================
-- DROP TABLES (in reverse dependency order)
-- ============================================================================

-- Drop dashboard and widget tables
DROP TABLE IF EXISTS user_role_widgets CASCADE;
DROP TABLE IF EXISTS dashboard_widgets CASCADE;

-- Drop system configuration
DROP TABLE IF EXISTS system_settings CASCADE;

-- Drop orders system (migration 002)
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;

-- Drop approval system (migration 001)
DROP TABLE IF EXISTS approval_history CASCADE;

-- Drop restaurant and menu tables
DROP TABLE IF EXISTS restaurant_menus CASCADE;
DROP TABLE IF EXISTS vendor_restaurants CASCADE;
DROP TABLE IF EXISTS menus CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;

-- Drop vendor management
DROP TABLE IF EXISTS vendor_users CASCADE;

-- Drop profile tables
DROP TABLE IF EXISTS customer_addresses CASCADE;
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;

-- Drop user authentication table
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================================
-- DROP CUSTOM TYPES/ENUMS
-- ============================================================================

-- Drop enums from migrations
DROP TYPE IF EXISTS setting_data_type CASCADE;  -- Migration 003_system_settings
DROP TYPE IF EXISTS approval_status CASCADE;    -- Migration 001
DROP TYPE IF EXISTS order_status CASCADE;       -- Migration 002 (extended enum)
DROP TYPE IF EXISTS user_status CASCADE;
DROP TYPE IF EXISTS user_type CASCADE;

-- ============================================================================
-- DROP FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS log_order_status_change() CASCADE;  -- Migration 002
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS set_user_role() CASCADE;

-- ============================================================================
-- DROP EXTENSIONS (optional - uncomment if needed)
-- ============================================================================

-- DROP EXTENSION IF EXISTS "uuid-ossp" CASCADE;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All database objects have been dropped!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Dropped objects:';
    RAISE NOTICE '  - 21 tables (including orders, approval_history, system_settings)';
    RAISE NOTICE '  - 5 custom enum types';
    RAISE NOTICE '  - 3 functions';
    RAISE NOTICE '  - All associated triggers, indexes, and constraints';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Database is now clean and ready for schema.sql';
    RAISE NOTICE '========================================';
END $$;
