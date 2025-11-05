# Stripe Connect Integration - Refined Architecture
**Delivery App - Split Payments with Optional Stripe Connect**
**Version:** 2.0
**Created:** 2025-01-03
**Status:** Ready for Implementation

---

## Executive Summary

This document provides the refined architectural design for Stripe Connect integration with the following key features:

### Key Features
1. **Commission Rate**: Uses existing `system_settings` API (already implemented)
2. **Optional Stripe Connect**: Restaurants can operate without Stripe (manual payout mode)
3. **Dual Payment Modes**:
   - **Direct Payout**: Restaurant has Stripe Connect → automatic split payments
   - **Manual Payout**: No Stripe Connect → platform holds funds, admin pays manually
4. **Flexible Payout Control**: Restaurant-level settings (automatic/manual/threshold)
5. **POS-Agnostic**: Abstraction layer for future integrations (Toast, Square, Clover)

### Updates from Original Plan
- ✅ Commission rate uses existing `system_settings` table (no new tables needed)
- ✅ Toast integration deferred with clean abstraction layer for future
- ✅ Stripe onboarding is optional during restaurant activation
- ✅ Restaurants can upgrade from manual → direct payout anytime
- ✅ Payout timing configurable per-restaurant

---

## Table of Contents
1. [System Settings Review](#1-system-settings-review)
2. [Database Schema](#2-database-schema)
3. [Dual Payment Flow](#3-dual-payment-flow)
4. [POS Integration Abstraction](#4-pos-integration-abstraction)
5. [API Endpoints](#5-api-endpoints)
6. [Migration Path](#6-migration-path)
7. [UI/UX Design](#7-uiux-design)
8. [Implementation Plan](#8-implementation-plan)

---

## 1. System Settings Review

### 1.1 Existing Commission Rate Configuration

**File:** `backend/sql/schema.sql` (lines 674-675)

```sql
('platform_commission_rate', '0.15', 'number', 'Platform commission rate (0.15 = 15%)', 'payments', true),
('driver_commission_rate', '0.10', 'number', 'Driver commission rate (0.10 = 10%)', 'payments', true),
```

**Status:** ✅ Already exists - no schema changes needed.

**API Access:**
```
GET /api/admin/settings?category=payments
PUT /api/admin/settings/platform_commission_rate
```

**Usage in Code:**
```go
// Retrieve commission rate from settings
commissionRate, err := h.App.Deps.Settings.GetDecimal("platform_commission_rate")
if err != nil {
    commissionRate = 0.15 // Default 15%
}
```

---

## 2. Database Schema

### 2.1 New Tables

#### `restaurant_stripe_accounts`
Tracks Stripe Connect accounts and payout preferences.

```sql
-- Migration: backend/sql/migrations/008_add_stripe_connect.sql

-- Payout schedule type enum
DO $$ BEGIN
    CREATE TYPE payout_schedule_type AS ENUM ('automatic', 'manual', 'threshold');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Restaurant Stripe Connect accounts
CREATE TABLE IF NOT EXISTS restaurant_stripe_accounts (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    restaurant_id INTEGER NOT NULL UNIQUE REFERENCES restaurants(id) ON DELETE CASCADE,

    -- Stripe Connect Account
    stripe_account_id VARCHAR(255) UNIQUE, -- acct_xxx (NULL if not onboarded)
    stripe_account_status VARCHAR(50), -- 'pending', 'active', 'restricted', 'disabled'
    charges_enabled BOOLEAN DEFAULT false,
    payouts_enabled BOOLEAN DEFAULT false,

    -- Payout Preferences (only applies if stripe_account_id exists)
    payout_schedule_type payout_schedule_type DEFAULT 'automatic',
    payout_threshold_amount DECIMAL(10, 2), -- Trigger payout when balance reaches this amount
    payout_interval VARCHAR(20), -- 'daily', 'weekly', 'monthly' (for automatic)

    -- Onboarding
    onboarding_completed_at TIMESTAMPTZ,
    onboarding_link VARCHAR(512), -- Stripe AccountLink for completing onboarding
    onboarding_link_expires_at TIMESTAMPTZ,

    -- Metadata
    details_submitted BOOLEAN DEFAULT false,
    account_type VARCHAR(50) DEFAULT 'express', -- 'standard', 'express', 'custom'
    country VARCHAR(2) DEFAULT 'US', -- ISO 3166-1 alpha-2
    default_currency VARCHAR(3) DEFAULT 'USD',

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_payout_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT valid_threshold_for_schedule CHECK (
        (payout_schedule_type != 'threshold') OR
        (payout_threshold_amount IS NOT NULL AND payout_threshold_amount > 0)
    )
);

-- Indexes
CREATE INDEX idx_restaurant_stripe_accounts_restaurant ON restaurant_stripe_accounts(restaurant_id);
CREATE INDEX idx_restaurant_stripe_accounts_stripe ON restaurant_stripe_accounts(stripe_account_id)
    WHERE stripe_account_id IS NOT NULL;
CREATE INDEX idx_restaurant_stripe_accounts_status ON restaurant_stripe_accounts(stripe_account_status);

-- Comments
COMMENT ON TABLE restaurant_stripe_accounts IS 'Stripe Connect account information and payout preferences. NULL stripe_account_id = manual payout mode.';
COMMENT ON COLUMN restaurant_stripe_accounts.stripe_account_id IS 'Stripe Connect Account ID (acct_xxx). NULL = manual payout mode, NOT NULL = direct payout mode';
COMMENT ON COLUMN restaurant_stripe_accounts.payout_schedule_type IS 'Payout timing: automatic (Stripe handles), manual (platform triggers), threshold (when balance hits amount)';

-- Trigger
DROP TRIGGER IF EXISTS update_restaurant_stripe_accounts_updated_at ON restaurant_stripe_accounts;
CREATE TRIGGER update_restaurant_stripe_accounts_updated_at
    BEFORE UPDATE ON restaurant_stripe_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### `pending_payouts`
Tracks what platform owes to restaurants in manual payout mode.

```sql
-- Pending payouts for manual mode restaurants
CREATE TABLE IF NOT EXISTS pending_payouts (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Amounts
    order_total DECIMAL(10, 2) NOT NULL, -- Full customer payment
    platform_commission DECIMAL(10, 2) NOT NULL, -- Platform's cut
    restaurant_net DECIMAL(10, 2) NOT NULL, -- What restaurant gets

    -- Commission calculation snapshot (for audit trail)
    commission_rate DECIMAL(5, 4) NOT NULL, -- e.g., 0.1500 for 15%

    -- Status
    payout_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'paid', 'failed'
    paid_at TIMESTAMPTZ,
    payout_method VARCHAR(50), -- 'stripe_transfer', 'manual_transfer', 'check'

    -- Stripe reference (if manual payout done via Stripe Transfer API)
    stripe_transfer_id VARCHAR(255),
    stripe_payout_id VARCHAR(255),

    -- Failure tracking
    failure_reason TEXT,
    retry_count INTEGER DEFAULT 0,

    -- Notes
    notes TEXT,
    processed_by INTEGER REFERENCES users(id) ON DELETE SET NULL, -- Admin who processed

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT pending_payouts_valid_amounts CHECK (
        order_total > 0 AND
        platform_commission >= 0 AND
        restaurant_net > 0 AND
        order_total = platform_commission + restaurant_net
    )
);

-- Indexes
CREATE INDEX idx_pending_payouts_restaurant ON pending_payouts(restaurant_id);
CREATE INDEX idx_pending_payouts_order ON pending_payouts(order_id);
CREATE INDEX idx_pending_payouts_status ON pending_payouts(payout_status);
CREATE INDEX idx_pending_payouts_created_at ON pending_payouts(created_at DESC);
CREATE INDEX idx_pending_payouts_pending ON pending_payouts(restaurant_id, payout_status)
    WHERE payout_status = 'pending';

-- Comments
COMMENT ON TABLE pending_payouts IS 'Tracks pending earnings for restaurants without Stripe Connect (manual payout mode). Each order creates one entry.';
COMMENT ON COLUMN pending_payouts.restaurant_net IS 'Amount owed to restaurant after platform commission (order_total - platform_commission)';
COMMENT ON COLUMN pending_payouts.commission_rate IS 'Snapshot of commission rate at time of order for audit trail';

-- Trigger
DROP TRIGGER IF EXISTS update_pending_payouts_updated_at ON pending_payouts;
CREATE TRIGGER update_pending_payouts_updated_at
    BEFORE UPDATE ON pending_payouts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 2.2 Modified Tables

#### `orders` Table Extensions

```sql
-- Add payment_mode column to orders table
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50) DEFAULT 'manual';
-- Values: 'direct' (Stripe destination charge), 'manual' (platform collects, manual payout later)

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS stripe_destination_account VARCHAR(255);
-- Stores the Stripe Connect account ID if payment_mode = 'direct'

CREATE INDEX IF NOT EXISTS idx_orders_payment_mode ON orders(payment_mode);

COMMENT ON COLUMN orders.payment_mode IS 'direct: restaurant has Stripe, use destination charges. manual: platform collects, manual payout later.';
COMMENT ON COLUMN orders.stripe_destination_account IS 'Stripe Connect account ID (acct_xxx) for destination charges. NULL for manual mode.';
```

#### `payments` Table Extensions

```sql
-- Extend payments table from original Stripe integration plan
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50) DEFAULT 'manual';

ALTER TABLE payments
ADD COLUMN IF NOT EXISTS destination_account_id VARCHAR(255);
-- Stripe Connect account for destination charges

ALTER TABLE payments
ADD COLUMN IF NOT EXISTS application_fee_amount DECIMAL(10, 2) DEFAULT 0.00;
-- Platform commission collected via Stripe (only for direct mode)

ALTER TABLE payments
ADD COLUMN IF NOT EXISTS transfer_amount DECIMAL(10, 2);
-- Amount transferred to restaurant (for direct mode)

COMMENT ON COLUMN payments.payment_mode IS 'Matches order.payment_mode - determines payment routing';
COMMENT ON COLUMN payments.destination_account_id IS 'Stripe Connect account for destination charges (direct mode only)';
COMMENT ON COLUMN payments.application_fee_amount IS 'Platform commission taken via Stripe application fee (direct mode only)';
```

### 2.3 Migration Script (Complete)

**File:** `backend/sql/migrations/008_add_stripe_connect.sql`

```sql
-- Migration: Add Stripe Connect support for split payments
-- Version: 1.0
-- Date: 2025-01-03

BEGIN;

-- Payout schedule type enum
DO $$ BEGIN
    CREATE TYPE payout_schedule_type AS ENUM ('automatic', 'manual', 'threshold');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Restaurant Stripe Connect accounts
CREATE TABLE IF NOT EXISTS restaurant_stripe_accounts (
    id SERIAL PRIMARY KEY,
    restaurant_id INTEGER NOT NULL UNIQUE REFERENCES restaurants(id) ON DELETE CASCADE,
    stripe_account_id VARCHAR(255) UNIQUE,
    stripe_account_status VARCHAR(50),
    charges_enabled BOOLEAN DEFAULT false,
    payouts_enabled BOOLEAN DEFAULT false,
    payout_schedule_type payout_schedule_type DEFAULT 'automatic',
    payout_threshold_amount DECIMAL(10, 2),
    payout_interval VARCHAR(20),
    onboarding_completed_at TIMESTAMPTZ,
    onboarding_link VARCHAR(512),
    onboarding_link_expires_at TIMESTAMPTZ,
    details_submitted BOOLEAN DEFAULT false,
    account_type VARCHAR(50) DEFAULT 'express',
    country VARCHAR(2) DEFAULT 'US',
    default_currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_payout_at TIMESTAMPTZ,
    CONSTRAINT valid_threshold_for_schedule CHECK (
        (payout_schedule_type != 'threshold') OR
        (payout_threshold_amount IS NOT NULL AND payout_threshold_amount > 0)
    )
);

CREATE INDEX idx_restaurant_stripe_accounts_restaurant ON restaurant_stripe_accounts(restaurant_id);
CREATE INDEX idx_restaurant_stripe_accounts_stripe ON restaurant_stripe_accounts(stripe_account_id)
    WHERE stripe_account_id IS NOT NULL;
CREATE INDEX idx_restaurant_stripe_accounts_status ON restaurant_stripe_accounts(stripe_account_status);

-- Pending payouts table
CREATE TABLE IF NOT EXISTS pending_payouts (
    id SERIAL PRIMARY KEY,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_total DECIMAL(10, 2) NOT NULL,
    platform_commission DECIMAL(10, 2) NOT NULL,
    restaurant_net DECIMAL(10, 2) NOT NULL,
    commission_rate DECIMAL(5, 4) NOT NULL,
    payout_status VARCHAR(50) DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    payout_method VARCHAR(50),
    stripe_transfer_id VARCHAR(255),
    stripe_payout_id VARCHAR(255),
    failure_reason TEXT,
    retry_count INTEGER DEFAULT 0,
    notes TEXT,
    processed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pending_payouts_valid_amounts CHECK (
        order_total > 0 AND
        platform_commission >= 0 AND
        restaurant_net > 0 AND
        order_total = platform_commission + restaurant_net
    )
);

CREATE INDEX idx_pending_payouts_restaurant ON pending_payouts(restaurant_id);
CREATE INDEX idx_pending_payouts_order ON pending_payouts(order_id);
CREATE INDEX idx_pending_payouts_status ON pending_payouts(payout_status);
CREATE INDEX idx_pending_payouts_created_at ON pending_payouts(created_at DESC);
CREATE INDEX idx_pending_payouts_pending ON pending_payouts(restaurant_id, payout_status)
    WHERE payout_status = 'pending';

-- Extend orders table
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50) DEFAULT 'manual',
ADD COLUMN IF NOT EXISTS stripe_destination_account VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_orders_payment_mode ON orders(payment_mode);

-- Extend payments table
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50) DEFAULT 'manual',
ADD COLUMN IF NOT EXISTS destination_account_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS application_fee_amount DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS transfer_amount DECIMAL(10, 2);

-- Populate restaurant_stripe_accounts for existing restaurants (manual mode by default)
INSERT INTO restaurant_stripe_accounts (restaurant_id, payout_schedule_type)
SELECT id, 'automatic'
FROM restaurants
WHERE id NOT IN (SELECT restaurant_id FROM restaurant_stripe_accounts);

-- Triggers
DROP TRIGGER IF EXISTS update_restaurant_stripe_accounts_updated_at ON restaurant_stripe_accounts;
CREATE TRIGGER update_restaurant_stripe_accounts_updated_at
    BEFORE UPDATE ON restaurant_stripe_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pending_payouts_updated_at ON pending_payouts;
CREATE TRIGGER update_pending_payouts_updated_at
    BEFORE UPDATE ON pending_payouts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
```

---

## 3. Dual Payment Flow

### 3.1 Flow A: Direct Payout (Restaurant with Stripe Connect)

**Prerequisites:**
- `restaurant_stripe_accounts.stripe_account_id IS NOT NULL`
- `restaurant_stripe_accounts.charges_enabled = true`

**Payment Flow Diagram:**

```
Customer                  Backend                 Stripe                Platform Account    Restaurant Account
   │                         │                       │                         │                    │
   │  1. Place Order         │                       │                         │                    │
   │     ($100 total)        │                       │                         │                    │
   ├────────────────────────►│                       │                         │                    │
   │                         │  2. Calculate:        │                         │                    │
   │                         │     Commission: $15   │                         │                    │
   │                         │     Restaurant: $85   │                         │                    │
   │                         │                       │                         │                    │
   │                         │  3. Create Payment Intent (Destination Charge)  │                    │
   │                         ├──────────────────────►│                         │                    │
   │                         │  {                    │                         │                    │
   │                         │    amount: 10000,     │                         │                    │
   │                         │    application_fee: 1500,                       │                    │
   │                         │    destination: acct_restaurant123              │                    │
   │                         │  }                    │                         │                    │
   │                         │◄──────────────────────┤                         │                    │
   │                         │  client_secret        │                         │                    │
   │◄────────────────────────┤                       │                         │                    │
   │                         │                       │                         │                    │
   │  4. Enter Card Details  │                       │                         │                    │
   ├─────────────────────────┼──────────────────────►│                         │                    │
   │                         │                       │  5. Charge Card $100    │                    │
   │                         │                       ├────────────────────────►│                    │
   │                         │                       │  6. Deduct $15 fee      │                    │
   │                         │                       │◄────────────────────────┤                    │
   │                         │                       │  7. Transfer $85        │                    │
   │                         │                       ├─────────────────────────┼───────────────────►│
   │                         │◄──────────────────────┤                         │                    │
   │◄────────────────────────┤  Payment confirmed    │                         │                    │
   │                         │                       │                         │                    │
   │                         │  8. Update DB:        │                         │                    │
   │                         │     order.payment_mode = 'direct'               │                    │
   │                         │     payment.application_fee = 15.00             │                    │
   │                         │     NO pending_payout record                    │                    │
```

**Database Records:**

```sql
-- orders table
INSERT INTO orders (id, restaurant_id, total_amount, payment_mode, stripe_destination_account)
VALUES (123, 5, 100.00, 'direct', 'acct_restaurant123');

-- payments table
INSERT INTO payments (order_id, amount, payment_mode, destination_account_id, application_fee_amount, status)
VALUES (123, 100.00, 'direct', 'acct_restaurant123', 15.00, 'succeeded');

-- NO pending_payouts record (money already transferred)
```

### 3.2 Flow B: Manual Payout (Restaurant without Stripe Connect)

**Prerequisites:**
- `restaurant_stripe_accounts.stripe_account_id IS NULL`

**Payment Flow Diagram:**

```
Customer                  Backend                 Stripe                Platform Account    Pending DB
   │                         │                       │                         │                │
   │  1. Place Order         │                       │                         │                │
   │     ($100 total)        │                       │                         │                │
   ├────────────────────────►│                       │                         │                │
   │                         │  2. Calculate:        │                         │                │
   │                         │     Commission: $15   │                         │                │
   │                         │     Restaurant: $85   │                         │                │
   │                         │                       │                         │                │
   │                         │  3. Create Payment Intent (Standard Charge)     │                │
   │                         ├──────────────────────►│                         │                │
   │                         │  {                    │                         │                │
   │                         │    amount: 10000,     │                         │                │
   │                         │    NO destination     │                         │                │
   │                         │  }                    │                         │                │
   │                         │◄──────────────────────┤                         │                │
   │◄────────────────────────┤  client_secret        │                         │                │
   │                         │                       │                         │                │
   │  4. Enter Card Details  │                       │                         │                │
   ├─────────────────────────┼──────────────────────►│                         │                │
   │                         │                       │  5. Charge Card $100    │                │
   │                         │                       ├────────────────────────►│                │
   │                         │◄──────────────────────┤  (Platform keeps all)   │                │
   │◄────────────────────────┤  Payment confirmed    │                         │                │
   │                         │                       │                         │                │
   │                         │  6. Update DB:        │                         │                │
   │                         │     order.payment_mode = 'manual'               │                │
   │                         │     Create pending_payout record                ├───────────────►│
   │                         │     {                 │                         │  Restaurant    │
   │                         │       order_total: 100.00,                      │  owes: $85     │
   │                         │       commission: 15.00,                        │                │
   │                         │       restaurant_net: 85.00,                    │                │
   │                         │       status: 'pending'                         │                │
   │                         │     }                 │                         │                │
```

**Database Records:**

```sql
-- orders table
INSERT INTO orders (id, restaurant_id, total_amount, payment_mode, stripe_destination_account)
VALUES (123, 5, 100.00, 'manual', NULL);

-- payments table
INSERT INTO payments (order_id, amount, payment_mode, destination_account_id, application_fee_amount, status)
VALUES (123, 100.00, 'manual', NULL, 0.00, 'succeeded');

-- pending_payouts table (platform owes restaurant)
INSERT INTO pending_payouts (restaurant_id, order_id, order_total, platform_commission, restaurant_net, commission_rate, payout_status)
VALUES (5, 123, 100.00, 15.00, 85.00, 0.1500, 'pending');
```

### 3.3 Manual Payout Process (Admin-Initiated)

```
Admin Dashboard          Backend                 Stripe                Restaurant Account
   │                         │                       │                         │
   │  1. View Pending        │                       │                         │
   │     Payouts             │                       │                         │
   ├────────────────────────►│                       │                         │
   │                         │  SELECT SUM(restaurant_net)                     │
   │                         │  FROM pending_payouts │                         │
   │                         │  WHERE restaurant_id = 5                        │
   │                         │  AND payout_status = 'pending'                  │
   │◄────────────────────────┤                       │                         │
   │  Total: $850 (10 orders)│                       │                         │
   │                         │                       │                         │
   │  2. Process Payout      │                       │                         │
   ├────────────────────────►│                       │                         │
   │                         │  3. Create Stripe Transfer (if restaurant has bank)
   │                         ├──────────────────────►│                         │
   │                         │  {                    │                         │
   │                         │    amount: 85000,     │                         │
   │                         │    destination: "ba_xxx" // bank account        │
   │                         │  }                    │                         │
   │                         │◄──────────────────────┤                         │
   │                         │  transfer_id: tr_xxx  │                         │
   │                         │                       │  Transfer $850          │
   │                         │                       ├────────────────────────►│
   │                         │                       │                         │
   │                         │  4. Update pending_payouts:                     │
   │                         │     SET payout_status = 'paid',                 │
   │                         │         paid_at = NOW(),                        │
   │                         │         stripe_transfer_id = 'tr_xxx'           │
   │◄────────────────────────┤                       │                         │
   │  Payout Complete        │                       │                         │
```

---

## 4. POS Integration Abstraction

### 4.1 POS Provider Interface

**File:** `backend/services/pos/interface.go`

```go
package pos

import (
    "context"
    "time"
)

// POSProvider defines the interface for Point of Sale integrations
type POSProvider interface {
    // Provider info
    GetProviderName() string
    IsEnabled(restaurantID int) bool

    // Menu synchronization
    SyncMenu(ctx context.Context, restaurantID int) (*MenuSyncResult, error)
    ImportMenu(ctx context.Context, restaurantID int, externalMenuID string) (*Menu, error)

    // Order management
    SendOrder(ctx context.Context, order *Order) (*POSOrderReference, error)
    UpdateOrderStatus(ctx context.Context, posOrderID string, status OrderStatus) error

    // Inventory (if supported)
    CheckItemAvailability(ctx context.Context, itemID string) (bool, error)
}

// MenuSyncResult contains the result of a menu sync operation
type MenuSyncResult struct {
    ItemsAdded    int
    ItemsUpdated  int
    ItemsRemoved  int
    Categories    []string
    LastSyncedAt  time.Time
    Errors        []string
}

// POSOrderReference contains POS system reference for an order
type POSOrderReference struct {
    POSOrderID    string
    ExternalID    string
    Status        string
    CreatedAt     time.Time
}

// Menu represents a POS menu structure
type Menu struct {
    ID         string
    Name       string
    Items      []MenuItem
    Categories []MenuCategory
}

// MenuItem represents a single menu item
type MenuItem struct {
    ID          string
    Name        string
    Description string
    Price       float64
    CategoryID  string
    Available   bool
    Modifiers   []MenuModifier
}

// MenuModifier represents item customizations
type MenuModifier struct {
    ID      string
    Name    string
    Price   float64
    Options []string
}

// MenuCategory represents a menu category
type MenuCategory struct {
    ID   string
    Name string
}

// Order represents an order to be sent to POS
type Order struct {
    ID              int
    ExternalID      string
    RestaurantID    int
    CustomerName    string
    Items           []OrderItem
    Subtotal        float64
    Tax             float64
    Total           float64
    SpecialNotes    string
    DeliveryInfo    DeliveryInfo
}

// OrderItem represents a single item in an order
type OrderItem struct {
    ID              string
    Name            string
    Quantity        int
    Price           float64
    Customizations  map[string]interface{}
}

// DeliveryInfo represents delivery details
type DeliveryInfo struct {
    CustomerName    string
    CustomerPhone   string
    Address         string
    Instructions    string
}

// OrderStatus represents order status
type OrderStatus string

const (
    OrderStatusPending   OrderStatus = "pending"
    OrderStatusConfirmed OrderStatus = "confirmed"
    OrderStatusPreparing OrderStatus = "preparing"
    OrderStatusReady     OrderStatus = "ready"
    OrderStatusCancelled OrderStatus = "cancelled"
)
```

### 4.2 POS Provider Registry

**File:** `backend/services/pos/registry.go`

```go
package pos

import (
    "fmt"
    "sync"
)

var (
    registeredProviders = make(map[string]POSProvider)
    mu                  sync.RWMutex
)

// RegisterProvider registers a POS provider
func RegisterProvider(name string, provider POSProvider) error {
    mu.Lock()
    defer mu.Unlock()

    if _, exists := registeredProviders[name]; exists {
        return fmt.Errorf("provider %s already registered", name)
    }

    registeredProviders[name] = provider
    return nil
}

// GetProvider retrieves a registered POS provider
func GetProvider(name string) (POSProvider, error) {
    mu.RLock()
    defer mu.RUnlock()

    provider, exists := registeredProviders[name]
    if !exists {
        return nil, fmt.Errorf("provider %s not found", name)
    }

    return provider, nil
}

// GetAllProviders returns all registered providers
func GetAllProviders() map[string]POSProvider {
    mu.RLock()
    defer mu.RUnlock()

    providers := make(map[string]POSProvider)
    for name, provider := range registeredProviders {
        providers[name] = provider
    }

    return providers
}

// Initialize registers all available POS providers
func Initialize() {
    // Future implementations:
    // RegisterProvider("toast", NewToastProvider(...))
    // RegisterProvider("square", NewSquareProvider(...))
    // RegisterProvider("clover", NewCloverProvider(...))
}
```

### 4.3 Future POS Provider Stubs

**File:** `backend/services/pos/toast_provider.go`

```go
package pos

import "context"

// ToastProvider implements POSProvider for Toast POS
type ToastProvider struct {
    apiKey      string
    apiSecret   string
    environment string
}

func NewToastProvider(apiKey, apiSecret, environment string) *ToastProvider {
    return &ToastProvider{
        apiKey:      apiKey,
        apiSecret:   apiSecret,
        environment: environment,
    }
}

func (t *ToastProvider) GetProviderName() string {
    return "toast"
}

func (t *ToastProvider) IsEnabled(restaurantID int) bool {
    // TODO: Check database for Toast integration status
    return false
}

func (t *ToastProvider) SyncMenu(ctx context.Context, restaurantID int) (*MenuSyncResult, error) {
    // TODO: Implement Toast API integration
    return nil, nil
}

// ... implement other interface methods
```

**File:** `backend/services/pos/square_provider.go`

```go
package pos

// SquareProvider implements POSProvider for Square POS
type SquareProvider struct {
    accessToken string
    locationID  string
}

func NewSquareProvider(accessToken, locationID string) *SquareProvider {
    return &SquareProvider{
        accessToken: accessToken,
        locationID:  locationID,
    }
}

func (s *SquareProvider) GetProviderName() string {
    return "square"
}

// ... implement interface methods
```

---

## 5. API Endpoints

### 5.1 Stripe Connect Onboarding

#### `POST /api/vendor/restaurants/{id}/stripe/onboard`

**Description:** Start Stripe Connect onboarding

**Auth:** Vendor (owns restaurant) or Admin

**Request:**
```json
{
  "return_url": "https://app.example.com/vendor/restaurants/5/settings",
  "refresh_url": "https://app.example.com/vendor/restaurants/5/stripe/onboard"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Stripe onboarding link created",
  "data": {
    "onboarding_url": "https://connect.stripe.com/setup/s/acct_xxx/yyy",
    "expires_at": "2025-01-04T12:00:00Z"
  }
}
```

#### `GET /api/vendor/restaurants/{id}/stripe/status`

**Description:** Check Stripe Connect account status

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "has_stripe_account": true,
    "stripe_account_id": "acct_xxx",
    "status": "active",
    "charges_enabled": true,
    "payouts_enabled": true,
    "onboarding_completed": true,
    "payment_mode": "direct",
    "payout_schedule": {
      "type": "automatic",
      "interval": "daily"
    }
  }
}
```

### 5.2 Restaurant Payment Settings

#### `GET /api/vendor/restaurants/{id}/payment-settings`

**Description:** Get restaurant payment configuration

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "payment_mode": "manual",
    "stripe_account": null,
    "payout_preferences": null,
    "pending_earnings": {
      "total_pending": 850.00,
      "order_count": 10,
      "oldest_date": "2025-01-01T10:00:00Z"
    }
  }
}
```

#### `PUT /api/vendor/restaurants/{id}/payout-preferences`

**Description:** Update payout schedule preferences

**Request:**
```json
{
  "schedule_type": "threshold",
  "threshold_amount": 500.00
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Payout preferences updated",
  "data": {
    "schedule_type": "threshold",
    "threshold_amount": 500.00
  }
}
```

### 5.3 Admin Payout Management

#### `GET /api/admin/restaurants/{id}/pending-earnings`

**Description:** Get pending payouts for a restaurant

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "restaurant_id": 5,
    "restaurant_name": "Pizza Palace",
    "payment_mode": "manual",
    "pending_payouts": [
      {
        "id": 101,
        "order_id": 123,
        "order_total": 100.00,
        "platform_commission": 15.00,
        "restaurant_net": 85.00,
        "created_at": "2025-01-03T10:30:00Z",
        "payout_status": "pending"
      }
    ],
    "summary": {
      "total_pending": 850.00,
      "total_commission": 150.00,
      "order_count": 10,
      "oldest_pending_date": "2025-01-01T10:00:00Z"
    }
  }
}
```

#### `POST /api/admin/restaurants/{id}/payout`

**Description:** Process manual payout

**Request:**
```json
{
  "payout_method": "stripe_transfer",
  "notes": "Weekly payout for week ending 2025-01-03"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Payout processed successfully",
  "data": {
    "payout_amount": 850.00,
    "order_count": 10,
    "payout_ids": [101, 102, 103],
    "stripe_transfer_id": "tr_xxx"
  }
}
```

#### `GET /api/admin/pending-payouts`

**Description:** Get all pending payouts

**Query Params:**
- `payment_mode=manual`
- `min_amount=100`
- `order_by=oldest`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "restaurant_id": 5,
      "restaurant_name": "Pizza Palace",
      "total_pending": 850.00,
      "order_count": 10,
      "oldest_pending": "2025-01-01T10:00:00Z"
    }
  ],
  "summary": {
    "total_pending_all": 2050.00,
    "restaurant_count": 2,
    "total_orders": 25
  }
}
```

### 5.4 Upgrade to Direct Payout

#### `POST /api/vendor/restaurants/{id}/upgrade-to-direct-payout`

**Description:** Upgrade from manual to direct payout

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Stripe onboarding started",
  "data": {
    "current_mode": "manual",
    "target_mode": "direct",
    "onboarding_url": "https://connect.stripe.com/setup/...",
    "pending_earnings_notice": {
      "total_pending": 850.00,
      "message": "Your pending earnings will be paid out once Stripe onboarding is complete"
    }
  }
}
```

---

## 6. Migration Path

### 6.1 Migration Strategy

**For existing restaurants:**

```sql
-- Run after schema migration
-- Populate restaurant_stripe_accounts for all existing restaurants
INSERT INTO restaurant_stripe_accounts (restaurant_id, payout_schedule_type)
SELECT id, 'automatic'
FROM restaurants
WHERE id NOT IN (SELECT restaurant_id FROM restaurant_stripe_accounts);
```

**Default Behavior:**
- All existing restaurants → manual payout mode
- New restaurants → manual payout mode
- No disruption to current operations

### 6.2 Order Creation Logic (Dual Mode)

**Updated CreateOrder Handler Pseudocode:**

```go
func CreateOrder(request CreateOrderRequest) {
    // 1. Get restaurant's Stripe account
    stripeAccount := GetRestaurantStripeAccount(request.RestaurantID)

    // 2. Determine payment mode
    paymentMode := "manual"
    destinationAccount := ""

    if stripeAccount.StripeAccountID != nil && stripeAccount.ChargesEnabled {
        paymentMode = "direct"
        destinationAccount = stripeAccount.StripeAccountID
    }

    // 3. Get commission rate from system settings
    commissionRate := GetSetting("platform_commission_rate") // 0.15

    // 4. Calculate amounts
    platformCommission := totalAmount * commissionRate
    restaurantNet := totalAmount - platformCommission

    // 5. Create Stripe Payment Intent
    if paymentMode == "direct" {
        // Destination charge
        paymentIntent := CreateDestinationCharge(
            amount: totalAmount,
            applicationFee: platformCommission,
            destination: destinationAccount
        )
    } else {
        // Standard charge
        paymentIntent := CreateStandardCharge(amount: totalAmount)
    }

    // 6. Create order record
    CreateOrder(paymentMode, destinationAccount)

    // 7. Create payment record
    CreatePayment(paymentIntent, paymentMode)

    // 8. If manual mode, create pending payout
    if paymentMode == "manual" {
        CreatePendingPayout(
            restaurantID,
            orderID,
            totalAmount,
            platformCommission,
            restaurantNet,
            commissionRate
        )
    }
}
```

---

## 7. UI/UX Design

### 7.1 Vendor Dashboard - Payment Settings

**Manual Payout Mode:**

```
┌──────────────────────────────────────────────┐
│ Payment Settings                             │
├──────────────────────────────────────────────┤
│                                              │
│ 💳 Payment Mode: Manual Payout               │
│                                              │
│ ⚠️  Payouts are processed manually by the   │
│     platform team                            │
│                                              │
│ 📊 Pending Earnings                          │
│    Total: $850.00 (10 orders)                │
│    Oldest pending: Jan 1, 2025               │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │ Upgrade to Direct Payout                 │ │
│ │                                          │ │
│ │ Get paid automatically via Stripe        │ │
│ │ • Faster payouts                         │ │
│ │ • Automatic split payments               │ │
│ │ • Better cash flow                       │ │
│ │                                          │ │
│ │ [Start Stripe Setup]                     │ │
│ └──────────────────────────────────────────┘ │
│                                              │
└──────────────────────────────────────────────┘
```

**Direct Payout Mode:**

```
┌──────────────────────────────────────────────┐
│ Payment Settings                             │
├──────────────────────────────────────────────┤
│                                              │
│ ✅ Payment Mode: Direct Payout (Stripe)      │
│                                              │
│ 🔗 Stripe Account: acct_1234567890           │
│    Status: Active                            │
│                                              │
│ 💰 Payout Schedule                           │
│    Current: Threshold ($500)                 │
│    ┌───────────────────────────────────────┐ │
│    │ ○ Automatic (Daily/Weekly/Monthly)    │ │
│    │ ○ Manual (You control when)           │ │
│    │ ● Threshold (When balance reaches)    │ │
│    │   Amount: $500.00                     │ │
│    └───────────────────────────────────────┘ │
│                                              │
│ [View Stripe Dashboard] [Update Settings]    │
│                                              │
└──────────────────────────────────────────────┘
```

### 7.2 Admin Dashboard - Pending Payouts

```
┌─────────────────────────────────────────────────────────────┐
│ Pending Payouts - Manual Mode Restaurants                  │
├─────────────────────────────────────────────────────────────┤
│ Total Pending: $2,050.00 across 2 restaurants (25 orders)  │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Restaurant       Pending    Orders  Oldest      Actions │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ Burger Haven    $1,200.00     15   Dec 30, 2024 [Pay]  │ │
│ │ Pizza Palace      $850.00     10   Jan 1, 2025   [Pay]  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ [Process Selected Payouts]                                  │
└─────────────────────────────────────────────────────────────┘
```

**Payout Modal:**

```
┌────────────────────────────────────────┐
│ Process Payout - Pizza Palace          │
├────────────────────────────────────────┤
│                                        │
│ Total Amount: $850.00                  │
│ Order Count: 10                        │
│ Date Range: Jan 1 - Jan 3, 2025        │
│                                        │
│ Payout Method:                         │
│ ○ Stripe Transfer (Instant)            │
│ ○ Manual Bank Transfer                 │
│ ○ Check                                │
│                                        │
│ Notes:                                 │
│ ┌────────────────────────────────────┐ │
│ │ Weekly payout for week ending...  │ │
│ └────────────────────────────────────┘ │
│                                        │
│ [Cancel]  [Process Payout]             │
└────────────────────────────────────────┘
```

---

## 8. Implementation Plan

### Phase 1: Foundation (Week 1-2)
- ✅ Run database migration (008_add_stripe_connect.sql)
- ✅ Create backend models (StripeConnectAccount, PendingPayout)
- ✅ Implement repository layer
- ✅ Update OpenAPI specification
- ✅ Commission rate integration (use existing system_settings)

**Deliverables:**
- Database schema live
- Models defined
- Repositories tested

### Phase 2: Dual Payment Flow (Week 3-4)
- ✅ Update CreateOrder handler for dual mode detection
- ✅ Implement Stripe Connect service (onboarding, account management)
- ✅ Implement destination charges
- ✅ Implement manual payout tracking
- ✅ Admin payout processing endpoints

**Deliverables:**
- Both payment flows working
- Webhook handling
- Unit tests passing

### Phase 3: Vendor UI (Week 5)
- ✅ Payment settings screen
- ✅ Stripe onboarding flow
- ✅ Pending earnings display
- ✅ Upgrade to direct payout button
- ✅ Payout schedule configuration

**Deliverables:**
- Vendor can view payment mode
- Vendor can upgrade to Stripe
- Vendor can configure payout schedule

### Phase 4: Admin Dashboard (Week 6)
- ✅ Pending payouts overview
- ✅ Manual payout processing UI
- ✅ Payout history
- ✅ Analytics and reporting

**Deliverables:**
- Admin can see all pending payouts
- Admin can process payouts
- Payout audit trail

### Phase 5: Testing & Documentation (Week 7)
- ✅ End-to-end testing (both flows)
- ✅ Stripe webhook testing
- ✅ Security audit
- ✅ Documentation updates
- ✅ Admin training materials

**Deliverables:**
- All tests passing
- Security validated
- Documentation complete

### Phase 6: POS Abstraction (Deferred)
- 🚧 Define POS interface (completed in this plan)
- 🚧 Create provider registry
- 🚧 Document integration guide
- ❌ Toast/Square/Clover implementations (future)

---

## 9. Key Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Commission Rate** | Use existing `system_settings` | Already implemented, no changes needed |
| **Toast Integration** | Deferred with abstraction layer | Focus on payments first, design for extensibility |
| **Stripe Onboarding** | Optional (manual mode default) | Lower barrier to entry for restaurants |
| **Payout Control** | Restaurant-level settings | Flexibility per restaurant |
| **Manual Payouts** | Track in `pending_payouts` table | Clear audit trail, admin control |
| **Payment Flow** | Dual mode (direct vs manual) | Support both models seamlessly |
| **Default Mode** | Manual payout | Safe default, opt-in to Stripe |

---

## 10. Files to Create/Modify

### Backend

**New Files:**
```
backend/sql/migrations/008_add_stripe_connect.sql
backend/models/stripe_connect.go
backend/models/pending_payout.go
backend/repositories/stripe_connect_repository.go
backend/repositories/pending_payout_repository.go
backend/services/stripe_connect_service.go
backend/handlers/stripe_connect.go
backend/services/pos/interface.go
backend/services/pos/registry.go
backend/services/pos/toast_provider.go (stub)
backend/openapi/paths/stripe_connect.yaml
backend/openapi/schemas/stripe_connect.yaml
```

**Modified Files:**
```
backend/handlers/order.go (dual payment mode logic)
backend/models/order.go (add payment_mode, stripe_destination_account)
backend/models/payment.go (extend for destination charges)
backend/database/database.go (add new repositories)
backend/main.go (add new routes)
backend/openapi.yaml (add new paths)
```

### Frontend

**New Files:**
```
frontend/lib/models/stripe_connect.dart
frontend/lib/models/pending_payout.dart
frontend/lib/services/stripe_connect_service.dart
frontend/lib/screens/vendor/payment_settings_screen.dart
frontend/lib/screens/admin/pending_payouts_screen.dart
frontend/lib/widgets/payment/payment_mode_card.dart
frontend/lib/widgets/payment/payout_schedule_selector.dart
```

**Modified Files:**
```
frontend/lib/screens/vendor/restaurant_settings_screen.dart
frontend/lib/services/restaurant_service.dart
```

---

## Next Steps

1. ✅ Review and approve this architectural plan
2. 🔄 Set up Stripe Connect test account
3. 🔄 Run database migration 008
4. 🔄 Begin Phase 1 implementation
5. 🔄 Create development task breakdown

---

**End of Document**
