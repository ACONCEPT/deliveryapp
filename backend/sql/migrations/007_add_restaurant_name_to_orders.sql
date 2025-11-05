-- Migration: Add restaurant_name column to orders table
-- Created: 2025-10-31
-- Author: Claude Code
-- Purpose: Store restaurant name at order creation time for display and historical accuracy

-- Step 1: Add restaurant_name column (allow NULL temporarily for backfill)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS restaurant_name VARCHAR(255);

-- Step 2: Backfill existing orders with restaurant names from restaurants table
UPDATE orders o
SET restaurant_name = r.name
FROM restaurants r
WHERE o.restaurant_id = r.id
  AND o.restaurant_name IS NULL;

-- Step 3: For any orphaned orders (restaurant was deleted), use a placeholder
UPDATE orders
SET restaurant_name = 'Restaurant (deleted)'
WHERE restaurant_name IS NULL;

-- Step 4: Make column NOT NULL now that all data is populated
ALTER TABLE orders ALTER COLUMN restaurant_name SET NOT NULL;

-- Step 5: Add comment explaining the field
COMMENT ON COLUMN orders.restaurant_name IS 'Restaurant name at time of order (denormalized for performance and historical accuracy)';
