-- Migration: Convert all TIMESTAMP columns to TIMESTAMPTZ
-- Created: 2025-10-30
-- Description: Adds timezone support to all timestamp columns in the database
--              This migration is safe for existing data - all timestamps are assumed to be UTC

-- ============================================================================
-- TIMEZONE INFRASTRUCTURE SETUP
-- ============================================================================

-- Add timezone column to restaurants
ALTER TABLE restaurants
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'UTC' NOT NULL;

-- Add timezone column to customer_addresses
ALTER TABLE customer_addresses
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);

-- Add indexes on timezone columns for performance
CREATE INDEX IF NOT EXISTS idx_restaurants_timezone ON restaurants(timezone);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_timezone ON customer_addresses(timezone);

-- Add comments explaining timezone fields
COMMENT ON COLUMN restaurants.timezone IS 'IANA timezone identifier (e.g., America/New_York, America/Los_Angeles). All order timestamps use the restaurant''s timezone for display.';
COMMENT ON COLUMN customer_addresses.timezone IS 'IANA timezone identifier for delivery address location. Optional field that can differ from restaurant timezone.';

-- ============================================================================
-- CONVERT TIMESTAMP TO TIMESTAMPTZ
-- ============================================================================

-- Users table
ALTER TABLE users
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Customers table
ALTER TABLE customers
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Customer addresses table
ALTER TABLE customer_addresses
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Vendors table
ALTER TABLE vendors
ALTER COLUMN approved_at TYPE TIMESTAMPTZ USING approved_at AT TIME ZONE 'UTC',
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Restaurants table
ALTER TABLE restaurants
ALTER COLUMN approved_at TYPE TIMESTAMPTZ USING approved_at AT TIME ZONE 'UTC',
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Menus table
ALTER TABLE menus
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Restaurant menus table
ALTER TABLE restaurant_menus
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Vendor restaurants table
ALTER TABLE vendor_restaurants
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Vendor users table
ALTER TABLE vendor_users
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Drivers table
ALTER TABLE drivers
ALTER COLUMN approved_at TYPE TIMESTAMPTZ USING approved_at AT TIME ZONE 'UTC',
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Admins table
ALTER TABLE admins
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Approval history table
ALTER TABLE approval_history
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC';

-- Orders table (CRITICAL - these are the main timestamp columns for business logic)
ALTER TABLE orders
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN placed_at TYPE TIMESTAMPTZ USING placed_at AT TIME ZONE 'UTC',
ALTER COLUMN confirmed_at TYPE TIMESTAMPTZ USING confirmed_at AT TIME ZONE 'UTC',
ALTER COLUMN ready_at TYPE TIMESTAMPTZ USING ready_at AT TIME ZONE 'UTC',
ALTER COLUMN delivered_at TYPE TIMESTAMPTZ USING delivered_at AT TIME ZONE 'UTC',
ALTER COLUMN cancelled_at TYPE TIMESTAMPTZ USING cancelled_at AT TIME ZONE 'UTC',
ALTER COLUMN estimated_delivery_time TYPE TIMESTAMPTZ USING estimated_delivery_time AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Order items table
ALTER TABLE order_items
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Order status history table
ALTER TABLE order_status_history
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC';

-- System settings table
ALTER TABLE system_settings
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Dashboard widgets table
ALTER TABLE dashboard_widgets
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- User role widgets table
ALTER TABLE user_role_widgets
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Messages table
ALTER TABLE messages
ALTER COLUMN read_at TYPE TIMESTAMPTZ USING read_at AT TIME ZONE 'UTC',
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC',
ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

-- Distance requests table
ALTER TABLE distance_requests
ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC';

-- ============================================================================
-- UPDATE TRIGGER FUNCTION TO USE TIMESTAMPTZ
-- ============================================================================

-- Replace the update_updated_at_column function to explicitly use TIMESTAMPTZ
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP AT TIME ZONE 'UTC';
    RETURN NEW;
END;
$$ language 'plpgsql';

COMMENT ON FUNCTION update_updated_at_column() IS 'Automatically sets updated_at to current UTC timestamp when a row is modified';

-- ============================================================================
-- UPDATE SEED DATA WITH TIMEZONE INFORMATION
-- ============================================================================

-- Update seed restaurants with appropriate timezones based on their city
UPDATE restaurants SET timezone = 'America/New_York' WHERE city = 'New York' AND timezone = 'UTC';
UPDATE restaurants SET timezone = 'America/Chicago' WHERE city = 'Chicago' AND timezone = 'UTC';
UPDATE restaurants SET timezone = 'America/Los_Angeles' WHERE city IN ('Los Angeles', 'San Francisco') AND timezone = 'UTC';
UPDATE restaurants SET timezone = 'America/Denver' WHERE city = 'Denver' AND timezone = 'UTC';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 006: TIMESTAMPTZ Conversion Complete';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All TIMESTAMP columns converted to TIMESTAMPTZ';
    RAISE NOTICE 'Timezone columns added to restaurants and customer_addresses';
    RAISE NOTICE 'All existing timestamps assumed to be UTC';
    RAISE NOTICE 'Restaurant timezone defaults set based on city';
    RAISE NOTICE '========================================';
END $$;