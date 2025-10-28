-- Migration: Add Admin Approval System
-- Created: 2025-10-22
-- Description: Adds approval workflow for vendors and restaurants
-- Phase: 0 (Critical foundation)

-- ============================================================================
-- STEP 1: Create approval_status enum type
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- STEP 2: Add approval columns to vendors table
-- ============================================================================
ALTER TABLE vendors
    ADD COLUMN IF NOT EXISTS approval_status approval_status DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS approved_by_admin_id INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- ============================================================================
-- STEP 3: Add approval columns to restaurants table
-- ============================================================================
ALTER TABLE restaurants
    ADD COLUMN IF NOT EXISTS approval_status approval_status DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS approved_by_admin_id INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- ============================================================================
-- STEP 4: Create approval_history table
-- ============================================================================
CREATE TABLE IF NOT EXISTS approval_history (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL, -- 'vendor' or 'restaurant'
    entity_id INTEGER NOT NULL,       -- ID of the vendor or restaurant
    admin_id INTEGER NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
    action approval_status NOT NULL,   -- 'approved' or 'rejected' (not 'pending')
    reason TEXT,                       -- Reason for rejection (NULL for approvals)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- STEP 5: Create indexes for performance
-- ============================================================================

-- Vendor approval indexes
CREATE INDEX IF NOT EXISTS idx_vendors_approval_status
    ON vendors(approval_status);

CREATE INDEX IF NOT EXISTS idx_vendors_approved_by
    ON vendors(approved_by_admin_id) WHERE approved_by_admin_id IS NOT NULL;

-- Restaurant approval indexes
CREATE INDEX IF NOT EXISTS idx_restaurants_approval_status
    ON restaurants(approval_status);

CREATE INDEX IF NOT EXISTS idx_restaurants_approved_by
    ON restaurants(approved_by_admin_id) WHERE approved_by_admin_id IS NOT NULL;

-- Approval history indexes
CREATE INDEX IF NOT EXISTS idx_approval_history_entity
    ON approval_history(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_approval_history_admin
    ON approval_history(admin_id);

CREATE INDEX IF NOT EXISTS idx_approval_history_action
    ON approval_history(action);

CREATE INDEX IF NOT EXISTS idx_approval_history_created_at
    ON approval_history(created_at DESC);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_approval_history_entity_admin
    ON approval_history(entity_type, entity_id, admin_id, created_at DESC);

-- ============================================================================
-- STEP 6: Backward compatibility - Mark existing data as approved
-- ============================================================================

-- Approve all existing vendors
UPDATE vendors
SET
    approval_status = 'approved',
    approved_at = created_at
WHERE approval_status = 'pending' OR approval_status IS NULL;

-- Approve all existing restaurants
UPDATE restaurants
SET
    approval_status = 'approved',
    approved_at = created_at
WHERE approval_status = 'pending' OR approval_status IS NULL;

-- ============================================================================
-- STEP 7: Add table comments for documentation
-- ============================================================================

COMMENT ON TABLE approval_history IS 'Audit trail for vendor and restaurant approval/rejection events';
COMMENT ON COLUMN approval_history.entity_type IS 'Type of entity being approved: vendor or restaurant';
COMMENT ON COLUMN approval_history.entity_id IS 'ID of the vendor or restaurant being approved/rejected';
COMMENT ON COLUMN approval_history.action IS 'Approval action taken: approved or rejected';
COMMENT ON COLUMN approval_history.reason IS 'Reason for rejection (NULL for approvals)';

COMMENT ON COLUMN vendors.approval_status IS 'Approval status: pending, approved, or rejected';
COMMENT ON COLUMN vendors.approved_by_admin_id IS 'Admin who approved/rejected the vendor';
COMMENT ON COLUMN vendors.approved_at IS 'Timestamp when vendor was approved';
COMMENT ON COLUMN vendors.rejection_reason IS 'Reason why vendor was rejected (NULL if not rejected)';

COMMENT ON COLUMN restaurants.approval_status IS 'Approval status: pending, approved, or rejected';
COMMENT ON COLUMN restaurants.approved_by_admin_id IS 'Admin who approved/rejected the restaurant';
COMMENT ON COLUMN restaurants.approved_at IS 'Timestamp when restaurant was approved';
COMMENT ON COLUMN restaurants.rejection_reason IS 'Reason why restaurant was rejected (NULL if not rejected)';

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- All existing vendors and restaurants are marked as 'approved' for backward compatibility
-- New vendors and restaurants will default to 'pending' status