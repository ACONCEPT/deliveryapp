-- Migration: Add Hours of Operation to Restaurants
-- Created: 2025-10-26
-- Description: Adds hours_of_operation JSONB field to restaurants table

-- ============================================================================
-- STEP 1: Add hours_of_operation column to restaurants table
-- ============================================================================
ALTER TABLE restaurants
    ADD COLUMN IF NOT EXISTS hours_of_operation JSONB;

-- ============================================================================
-- STEP 2: Add index for JSONB queries (optional but recommended)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_restaurants_hours_of_operation
    ON restaurants USING GIN (hours_of_operation);

-- ============================================================================
-- STEP 3: Add table comment for documentation
-- ============================================================================
COMMENT ON COLUMN restaurants.hours_of_operation IS 'Weekly operating hours in JSONB format. Structure: {"monday": {"open": "09:00", "close": "22:00", "closed": false}, ...}';

-- ============================================================================
-- STEP 4: Add sample data for existing restaurants (optional)
-- ============================================================================
-- Example: Set default hours for existing restaurants without hours
UPDATE restaurants
SET hours_of_operation = jsonb_build_object(
    'monday', jsonb_build_object('open', '09:00', 'close', '22:00', 'closed', false),
    'tuesday', jsonb_build_object('open', '09:00', 'close', '22:00', 'closed', false),
    'wednesday', jsonb_build_object('open', '09:00', 'close', '22:00', 'closed', false),
    'thursday', jsonb_build_object('open', '09:00', 'close', '22:00', 'closed', false),
    'friday', jsonb_build_object('open', '09:00', 'close', '23:00', 'closed', false),
    'saturday', jsonb_build_object('open', '10:00', 'close', '23:00', 'closed', false),
    'sunday', jsonb_build_object('open', '10:00', 'close', '22:00', 'closed', false)
)
WHERE hours_of_operation IS NULL;

-- ============================================================================
-- Migration Complete
-- ============================================================================
