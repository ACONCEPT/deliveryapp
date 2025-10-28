-- Migration: Add vendor_id to menus table
-- This allows tracking which vendor owns each menu

-- Add vendor_id column
ALTER TABLE menus
ADD COLUMN vendor_id INTEGER REFERENCES vendors(id) ON DELETE CASCADE;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_menus_vendor_id ON menus(vendor_id);

-- Update existing menus to assign them to a vendor (if any exist)
-- This links menus to vendors through their restaurant assignments
UPDATE menus m
SET vendor_id = (
    SELECT vr.vendor_id
    FROM restaurant_menus rm
    JOIN vendor_restaurants vr ON rm.restaurant_id = vr.restaurant_id
    WHERE rm.menu_id = m.id
    LIMIT 1
)
WHERE m.vendor_id IS NULL;

-- Comment
COMMENT ON COLUMN menus.vendor_id IS 'Vendor who created/owns this menu';
