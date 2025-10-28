-- Migration: Add Orders System
-- Phase 1: Core Order System
-- Adds orders, order_items, and order_status_history tables

-- ============================================================================
-- ENUMS
-- ============================================================================

-- Order Status Enum (extends existing one to include cart and more states)
DROP TYPE IF EXISTS order_status CASCADE;
CREATE TYPE order_status AS ENUM (
    'cart',              -- Customer building order
    'pending',           -- Order placed, awaiting vendor confirmation
    'confirmed',         -- Vendor confirmed
    'preparing',         -- Vendor preparing food
    'ready',             -- Ready for pickup
    'driver_assigned',   -- Driver assigned
    'picked_up',         -- Driver picked up order
    'in_transit',        -- On the way to customer
    'delivered',         -- Successfully delivered
    'cancelled',         -- Cancelled by customer/vendor/system
    'refunded'           -- Payment refunded
);

-- ============================================================================
-- TABLES
-- ============================================================================

-- Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    delivery_address_id INTEGER REFERENCES customer_addresses(id) ON DELETE SET NULL,
    driver_id INTEGER REFERENCES drivers(id) ON DELETE SET NULL,

    -- Status
    status order_status NOT NULL DEFAULT 'pending',

    -- Amounts (in cents to avoid floating point issues, or use DECIMAL)
    subtotal_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    placed_at TIMESTAMP,  -- When customer placed order
    confirmed_at TIMESTAMP,  -- When vendor confirmed
    ready_at TIMESTAMP,  -- When order ready for pickup
    delivered_at TIMESTAMP,  -- When delivered
    cancelled_at TIMESTAMP,  -- When cancelled
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Additional Info
    special_instructions TEXT,
    cancellation_reason TEXT,
    estimated_preparation_time INTEGER,  -- in minutes
    estimated_delivery_time TIMESTAMP,

    -- Metadata
    is_active BOOLEAN DEFAULT true,

    CONSTRAINT orders_positive_amounts CHECK (
        subtotal_amount >= 0 AND
        tax_amount >= 0 AND
        delivery_fee >= 0 AND
        discount_amount >= 0 AND
        total_amount >= 0
    )
);

-- Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,

    -- Foreign Key
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Item Details (stored at time of order to preserve historical pricing)
    menu_item_name VARCHAR(255) NOT NULL,
    menu_item_description TEXT,
    price_at_time DECIMAL(10, 2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,

    -- Customizations (JSONB for flexibility)
    customizations JSONB,

    -- Calculated
    line_total DECIMAL(10, 2) NOT NULL,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT order_items_positive_quantity CHECK (quantity > 0),
    CONSTRAINT order_items_positive_price CHECK (price_at_time >= 0),
    CONSTRAINT order_items_positive_total CHECK (line_total >= 0)
);

-- Order Status History Table (audit trail)
CREATE TABLE IF NOT EXISTS order_status_history (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,  -- Who made the change

    -- Status Change
    from_status order_status,
    to_status order_status NOT NULL,

    -- Additional Info
    notes TEXT,
    metadata JSONB,  -- Additional context (e.g., reason codes, system info)

    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Orders indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_id ON orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_address_id ON orders(delivery_address_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_placed_at ON orders(placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_is_active ON orders(is_active);

-- Composite index for vendor queries (restaurant + status)
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_status ON orders(restaurant_id, status);

-- Composite index for customer queries (customer + status)
CREATE INDEX IF NOT EXISTS idx_orders_customer_status ON orders(customer_id, status);

-- Order Items indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Order Status History indexes
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_user_id ON order_status_history(user_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_created_at ON order_status_history(created_at DESC);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp on orders
CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp on order_items
CREATE OR REPLACE FUNCTION update_order_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically log status changes to history
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO order_status_history (order_id, from_status, to_status)
        VALUES (NEW.id, OLD.status, NEW.status);
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO order_status_history (order_id, from_status, to_status)
        VALUES (NEW.id, NULL, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger for updating orders.updated_at
DROP TRIGGER IF EXISTS trigger_update_orders_updated_at ON orders;
CREATE TRIGGER trigger_update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_orders_updated_at();

-- Trigger for updating order_items.updated_at
DROP TRIGGER IF EXISTS trigger_update_order_items_updated_at ON order_items;
CREATE TRIGGER trigger_update_order_items_updated_at
    BEFORE UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_items_updated_at();

-- Trigger for logging status changes
DROP TRIGGER IF EXISTS trigger_log_order_status_change ON orders;
CREATE TRIGGER trigger_log_order_status_change
    AFTER INSERT OR UPDATE OF status ON orders
    FOR EACH ROW
    EXECUTE FUNCTION log_order_status_change();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE orders IS 'Main orders table tracking customer orders from creation to delivery';
COMMENT ON TABLE order_items IS 'Line items for each order, preserving historical pricing and customizations';
COMMENT ON TABLE order_status_history IS 'Audit trail for order status changes';

COMMENT ON COLUMN orders.subtotal_amount IS 'Sum of all order items before tax and fees';
COMMENT ON COLUMN orders.tax_amount IS 'Calculated tax amount based on location';
COMMENT ON COLUMN orders.delivery_fee IS 'Delivery fee charged to customer';
COMMENT ON COLUMN orders.discount_amount IS 'Total discounts applied (promos, coupons)';
COMMENT ON COLUMN orders.total_amount IS 'Final amount: subtotal + tax + delivery_fee - discount_amount';
COMMENT ON COLUMN orders.estimated_preparation_time IS 'Vendor estimated prep time in minutes';

COMMENT ON COLUMN order_items.customizations IS 'JSONB field for item customizations (e.g., {"size": "large", "toppings": ["cheese", "olives"]})';
COMMENT ON COLUMN order_items.line_total IS 'Calculated as price_at_time * quantity';

COMMENT ON COLUMN order_status_history.metadata IS 'Additional context in JSONB format (e.g., {"ip": "...", "user_agent": "..."})';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✓ Migration 002: Orders system tables created successfully';
END $$;
