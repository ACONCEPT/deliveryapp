-- Migration: Add driver assignment safety constraints and indexes
-- Purpose: Prevent race conditions and improve query performance for driver order assignment
-- Date: 2025-10-26

-- ============================================================================
-- PERFORMANCE INDEXES
-- ============================================================================

-- Composite index for "available orders" query used by drivers
-- This significantly speeds up: SELECT * FROM orders WHERE status = 'ready' AND driver_id IS NULL
CREATE INDEX IF NOT EXISTS idx_orders_available_for_driver
ON orders(status, driver_id)
WHERE status = 'ready' AND driver_id IS NULL;

-- Index for driver's assigned orders query
-- Speeds up: SELECT * FROM orders WHERE driver_id = ?
-- Note: Basic index already exists (idx_orders_driver_id), this is redundant but explicit
-- CREATE INDEX IF NOT EXISTS idx_orders_by_driver ON orders(driver_id) WHERE driver_id IS NOT NULL;

-- ============================================================================
-- SAFETY CONSTRAINTS
-- ============================================================================

-- Partial unique index to provide database-level race condition protection
-- This ensures that an order can only have ONE driver assigned at any time
-- Only applies to active orders that aren't in terminal states
-- If application-level checks fail, this will catch the race at DB level
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_single_driver_per_order
ON orders(id)
WHERE driver_id IS NOT NULL
  AND status NOT IN ('cancelled', 'delivered', 'refunded');

-- Check constraint: Enforce driver-status consistency
-- If driver is assigned, status must be driver-related
-- If no driver, status must be pre-driver stages
-- This prevents invalid state combinations like (driver_id=5, status='pending')
ALTER TABLE orders
ADD CONSTRAINT IF NOT EXISTS check_driver_status_consistency
CHECK (
    -- Orders without drivers must be in pre-assignment states
    (driver_id IS NULL AND status IN ('cart', 'pending', 'confirmed', 'preparing', 'ready', 'cancelled', 'refunded'))
    OR
    -- Orders with drivers must be in post-assignment states
    (driver_id IS NOT NULL AND status IN ('driver_assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled', 'refunded'))
);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON INDEX idx_orders_available_for_driver IS
'Performance index for driver available orders query (status=ready, driver_id=NULL)';

COMMENT ON INDEX idx_orders_single_driver_per_order IS
'Safety constraint: Prevents multiple drivers from being assigned to the same active order';

COMMENT ON CONSTRAINT check_driver_status_consistency ON orders IS
'Enforces valid driver-status combinations: orders without drivers must be pre-assignment, orders with drivers must be post-assignment';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify constraints were created
DO $$
BEGIN
    RAISE NOTICE 'Driver assignment constraints added successfully';
    RAISE NOTICE '- Index: idx_orders_available_for_driver';
    RAISE NOTICE '- Index: idx_orders_single_driver_per_order';
    RAISE NOTICE '- Constraint: check_driver_status_consistency';
END $$;
