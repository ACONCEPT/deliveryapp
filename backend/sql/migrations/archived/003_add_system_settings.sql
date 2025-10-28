-- Migration: Add System Settings
-- Adds system_settings table for configurable application settings
-- Admin-only management with type validation and categorization

-- ============================================================================
-- ENUMS
-- ============================================================================

-- Data Type Enum for setting values
CREATE TYPE setting_data_type AS ENUM (
    'string',
    'number',
    'boolean',
    'json'
);

-- ============================================================================
-- TABLES
-- ============================================================================

-- System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,

    -- Setting Key (unique identifier)
    setting_key VARCHAR(255) NOT NULL UNIQUE,

    -- Setting Value (stored as text, parsed based on data_type)
    setting_value TEXT NOT NULL,

    -- Data Type (for validation and parsing)
    data_type setting_data_type NOT NULL DEFAULT 'string',

    -- Metadata
    description TEXT,
    category VARCHAR(100),
    is_editable BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Unique index on setting_key (already enforced by UNIQUE constraint, but explicit)
CREATE UNIQUE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(setting_key);

-- Index on category for filtering settings by category
CREATE INDEX IF NOT EXISTS idx_system_settings_category ON system_settings(category);

-- Index on is_editable for filtering editable vs read-only settings
CREATE INDEX IF NOT EXISTS idx_system_settings_editable ON system_settings(is_editable);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp on system_settings
CREATE OR REPLACE FUNCTION update_system_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger for updating system_settings.updated_at
DROP TRIGGER IF EXISTS trigger_update_system_settings_updated_at ON system_settings;
CREATE TRIGGER trigger_update_system_settings_updated_at
    BEFORE UPDATE ON system_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_system_settings_updated_at();

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Insert initial system settings
INSERT INTO system_settings (setting_key, setting_value, data_type, description, category, is_editable) VALUES
    -- Order Settings
    ('minimum_order_amount', '10.00', 'number', 'Minimum order subtotal required in dollars', 'orders', true),
    ('tax_rate', '0.085', 'number', 'Sales tax rate (0.085 = 8.5%)', 'orders', true),
    ('default_delivery_fee', '5.00', 'number', 'Default delivery fee amount in dollars', 'orders', true),
    ('order_auto_cancel_minutes', '30', 'number', 'Minutes before unconfirmed orders auto-cancel', 'orders', true),

    -- Payment Settings
    ('platform_commission_rate', '0.15', 'number', 'Platform commission rate (0.15 = 15%)', 'payments', true),
    ('driver_commission_rate', '0.10', 'number', 'Driver commission rate (0.10 = 10%)', 'payments', true),

    -- Delivery Settings
    ('max_delivery_radius_km', '20.0', 'number', 'Maximum delivery radius in kilometers', 'delivery', true),
    ('estimated_prep_time_default', '30', 'number', 'Default preparation time in minutes if not specified', 'delivery', true),
    ('estimated_delivery_time_per_km', '2', 'number', 'Estimated delivery time per kilometer in minutes', 'delivery', true),

    -- System Settings
    ('maintenance_mode', 'false', 'boolean', 'Enable maintenance mode (disables new orders)', 'system', true),
    ('allow_new_registrations', 'true', 'boolean', 'Allow new user registrations', 'system', true),
    ('require_vendor_approval', 'true', 'boolean', 'Require admin approval for new vendors', 'system', true),
    ('require_restaurant_approval', 'true', 'boolean', 'Require admin approval for new restaurants', 'system', true),

    -- Business Settings
    ('support_email', 'support@deliveryapp.com', 'string', 'Customer support email address', 'business', true),
    ('support_phone', '1-800-DELIVERY', 'string', 'Customer support phone number', 'business', true),
    ('business_name', 'DeliveryApp', 'string', 'Business name for branding', 'business', false),
    ('terms_url', 'https://deliveryapp.com/terms', 'string', 'Terms of service URL', 'business', true),
    ('privacy_url', 'https://deliveryapp.com/privacy', 'string', 'Privacy policy URL', 'business', true)
ON CONFLICT (setting_key) DO NOTHING;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE system_settings IS 'System-wide configuration settings managed by admins';
COMMENT ON COLUMN system_settings.setting_key IS 'Unique key identifier for the setting';
COMMENT ON COLUMN system_settings.setting_value IS 'Setting value stored as text, parsed based on data_type';
COMMENT ON COLUMN system_settings.data_type IS 'Data type for validation: string, number, boolean, or json';
COMMENT ON COLUMN system_settings.description IS 'Human-readable description of what the setting controls';
COMMENT ON COLUMN system_settings.category IS 'Category grouping (e.g., orders, payments, delivery, system)';
COMMENT ON COLUMN system_settings.is_editable IS 'Whether the setting can be modified via API (false = read-only)';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✓ Migration 003: System settings table created successfully';
    RAISE NOTICE '✓ Seeded 18 initial system settings';
END $$;
