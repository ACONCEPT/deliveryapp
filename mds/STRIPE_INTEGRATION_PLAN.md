# Stripe Integration Development Plan
**Delivery App - Payment Processing System**
**Created:** 2025-01-03
**Version:** 1.0

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current System Analysis](#current-system-analysis)
3. [Architecture Design](#architecture-design)
4. [Development Phases](#development-phases)
5. [Database Schema](#database-schema)
6. [API Endpoints](#api-endpoints)
7. [Security Considerations](#security-considerations)
8. [Testing Strategy](#testing-strategy)
9. [Deployment Plan](#deployment-plan)

---

## Executive Summary

This plan outlines the integration of Stripe payment processing into the delivery app, enabling secure payment collection for customer orders with support for multiple payment methods, refunds, and comprehensive transaction tracking.

### Goals
- ✅ Secure credit/debit card payments via Stripe
- ✅ Support for saved payment methods (customer wallets)
- ✅ Automatic payment capture on order placement
- ✅ Refund support for cancellations
- ✅ Payment intent tracking for dispute resolution
- ✅ Support for future expansion (Apple Pay, Google Pay, etc.)

### Key Metrics
- **Payment Success Rate Target:** 95%+
- **Average Transaction Time:** < 3 seconds
- **PCI Compliance:** Achieved via Stripe (no card data touches our servers)
- **Refund Processing:** < 24 hours

---

## Current System Analysis

### Existing Order Flow
```
1. Customer adds items to cart
2. Customer navigates to checkout
3. Customer selects delivery address
4. Customer reviews order
5. ❌ Order created with status 'pending' (NO PAYMENT)
6. Order visible to vendor for confirmation
```

### Current Database Schema
**Orders Table** (`backend/sql/schema.sql:499-544`)
- Has `total_amount`, `subtotal_amount`, `tax_amount`, `delivery_fee`
- ❌ **Missing:** Payment method tracking
- ❌ **Missing:** Payment intent/transaction ID
- ❌ **Missing:** Payment status
- ❌ **Missing:** Refund tracking

**Missing Tables:**
- `payment_methods` - Customer saved cards
- `payments` - Transaction records
- `refunds` - Refund tracking

### Current Frontend Flow
**Checkout Screen** (`frontend/lib/screens/customer/checkout_screen.dart`)
- Validates address selection
- Shows order summary
- Creates order via API
- ❌ **Missing:** Payment method selection
- ❌ **Missing:** Stripe integration

---

## Architecture Design

### High-Level Architecture

```
┌─────────────┐
│   Flutter   │
│   Frontend  │
└──────┬──────┘
       │ 1. Create Payment Intent
       ▼
┌─────────────┐      3. Confirm Payment      ┌─────────────┐
│     Go      │◄────────────────────────────►│   Stripe    │
│   Backend   │                               │     API     │
└──────┬──────┘                               └─────────────┘
       │ 2. Store Payment Intent ID
       │ 4. Update Order Status
       ▼
┌─────────────┐
│ PostgreSQL  │
│  Database   │
└─────────────┘
```

### Payment Flow

#### Phase 1: Order Creation with Payment Intent
```
1. Customer clicks "Place Order"
2. Frontend → Backend: POST /api/customer/orders
   {
     "restaurant_id": 1,
     "delivery_address_id": 5,
     "items": [...],
     "special_instructions": "..."
   }

3. Backend:
   a. Calculate total amount
   b. Create Stripe Payment Intent
   c. Create order record (status: 'pending_payment')
   d. Store payment_intent_id in payments table
   e. Return payment intent client_secret + order_id

4. Frontend receives:
   {
     "order_id": 123,
     "client_secret": "pi_xxx_secret_yyy",
     "total_amount": 45.99
   }
```

#### Phase 2: Payment Confirmation
```
5. Frontend:
   a. Display Stripe Card Element
   b. Customer enters card details (PCI compliant, data goes to Stripe)
   c. Customer clicks "Confirm Payment"
   d. Stripe.confirmPayment(client_secret, card_details)

6. Stripe processes payment:
   - Validates card
   - Authorizes transaction
   - Captures funds
   - Returns success/failure

7. Frontend → Backend: PUT /api/customer/orders/{id}/confirm-payment
   {
     "payment_intent_id": "pi_xxx"
   }

8. Backend:
   a. Verify payment status with Stripe API
   b. Update order status: 'pending_payment' → 'pending'
   c. Update payments table with confirmation
   d. Send confirmation to vendor
   e. Return success
```

#### Phase 3: Refund Flow
```
1. Customer/Admin cancels order
2. Backend checks if payment was captured
3. If yes:
   a. Create Stripe Refund
   b. Create refunds table entry
   c. Update order status → 'refunded'
   d. Update payments table
4. If no: Simple cancellation (no refund needed)
```

### Component Responsibilities

#### **Backend (Go)**
- Create/retrieve Stripe Payment Intents
- Verify payment status
- Handle webhooks from Stripe
- Store transaction records
- Process refunds
- **Security:** API key management, webhook signature verification

#### **Frontend (Flutter)**
- Display Stripe Card Element (flutter_stripe package)
- Collect card details securely
- Confirm payments with Stripe
- Handle 3D Secure authentication
- Display payment status

#### **Database (PostgreSQL)**
- Store payment method metadata (NOT card numbers)
- Track payment intents
- Record refund history
- Audit trail

---

## Development Phases

### **Phase 1: Foundation** (Week 1)
**Goal:** Set up Stripe account, database schema, and basic backend infrastructure

#### Tasks
1. **Stripe Account Setup**
   - [ ] Create Stripe account
   - [ ] Get API keys (test + production)
   - [ ] Configure webhook endpoints
   - [ ] Set up Stripe Dashboard

2. **Database Schema**
   - [ ] Create `payment_methods` table
   - [ ] Create `payments` table
   - [ ] Create `refunds` table
   - [ ] Add migration script
   - [ ] Update `orders` table (add payment_status column)

3. **Backend Dependencies**
   - [ ] Add `stripe-go` package to Go project
   - [ ] Create Stripe client wrapper
   - [ ] Add payment configuration to `.env`
   - [ ] Update config.go

4. **Documentation**
   - [ ] Update OpenAPI spec with payment endpoints
   - [ ] Document payment flow diagrams
   - [ ] Security best practices document

**Deliverables:**
- ✅ Database schema ready
- ✅ Stripe test account configured
- ✅ Backend dependencies installed
- ✅ OpenAPI spec updated

---

### **Phase 2: Backend Implementation** (Week 2)
**Goal:** Implement payment processing on the backend

#### Tasks
1. **Data Models** (`backend/models/payment.go`)
   - [ ] PaymentMethod struct
   - [ ] Payment struct
   - [ ] Refund struct
   - [ ] Request/Response DTOs

2. **Repository Layer** (`backend/repositories/payment_repository.go`)
   - [ ] CreatePaymentMethod
   - [ ] GetPaymentMethodsByCustomer
   - [ ] SetDefaultPaymentMethod
   - [ ] DeletePaymentMethod
   - [ ] CreatePayment
   - [ ] GetPaymentByOrderID
   - [ ] CreateRefund

3. **Stripe Service** (`backend/services/stripe_service.go`)
   - [ ] InitializeStripeClient
   - [ ] CreatePaymentIntent
   - [ ] RetrievePaymentIntent
   - [ ] ConfirmPaymentIntent
   - [ ] CreateRefund
   - [ ] HandleWebhook (payment_intent.succeeded, etc.)

4. **Handlers** (`backend/handlers/payment.go`)
   - [ ] POST /api/customer/payment-methods (save card)
   - [ ] GET /api/customer/payment-methods
   - [ ] DELETE /api/customer/payment-methods/:id
   - [ ] POST /api/customer/orders/:id/create-payment-intent
   - [ ] PUT /api/customer/orders/:id/confirm-payment
   - [ ] POST /api/admin/orders/:id/refund

5. **Update Order Handler** (`backend/handlers/order.go`)
   - [ ] Modify CreateOrder to create payment intent
   - [ ] Add payment verification to order confirmation
   - [ ] Add refund logic to order cancellation

6. **Webhook Handler** (`backend/handlers/stripe_webhook.go`)
   - [ ] POST /api/webhooks/stripe
   - [ ] Signature verification
   - [ ] Handle payment_intent.succeeded
   - [ ] Handle payment_intent.payment_failed
   - [ ] Handle charge.refunded

**Deliverables:**
- ✅ Payment endpoints functional
- ✅ Stripe integration working
- ✅ Webhook handling implemented
- ✅ Unit tests passing

---

### **Phase 3: Frontend Implementation** (Week 3)
**Goal:** Build payment UI in Flutter

#### Tasks
1. **Dependencies** (`frontend/pubspec.yaml`)
   - [ ] Add `flutter_stripe` package
   - [ ] Add `stripe_platform_interface`

2. **Models** (`frontend/lib/models/payment.dart`)
   - [ ] PaymentMethod model
   - [ ] Payment model
   - [ ] PaymentIntent model

3. **Services** (`frontend/lib/services/payment_service.dart`)
   - [ ] getPaymentMethods
   - [ ] savePaymentMethod
   - [ ] deletePaymentMethod
   - [ ] createPaymentIntent
   - [ ] confirmPayment

4. **Widgets**
   - [ ] `widgets/payment/payment_method_card.dart` - Display saved cards
   - [ ] `widgets/payment/payment_method_form.dart` - Add new card
   - [ ] `widgets/payment/stripe_card_field.dart` - Stripe card input

5. **Screens**
   - [ ] `screens/customer/payment_methods_screen.dart` - Manage saved cards
   - [ ] Update `screens/customer/checkout_screen.dart`:
     - Add payment method selection
     - Integrate Stripe payment flow
     - Handle 3D Secure authentication
     - Show payment confirmation

6. **State Management**
   - [ ] Create `providers/payment_provider.dart`
   - [ ] Manage selected payment method
   - [ ] Handle payment intent state

**Deliverables:**
- ✅ Payment method management UI
- ✅ Checkout payment flow
- ✅ 3D Secure support
- ✅ Error handling

---

### **Phase 4: Testing & Refinement** (Week 4)
**Goal:** Comprehensive testing and bug fixes

#### Tasks
1. **Backend Testing**
   - [ ] Unit tests for payment repository
   - [ ] Integration tests for Stripe service
   - [ ] API endpoint tests
   - [ ] Webhook handler tests
   - [ ] Refund flow tests

2. **Frontend Testing**
   - [ ] Widget tests for payment UI
   - [ ] Integration tests for checkout flow
   - [ ] Test Stripe card element
   - [ ] Test error scenarios

3. **E2E Testing**
   - [ ] Complete order with payment
   - [ ] Save payment method
   - [ ] Cancel order with refund
   - [ ] Failed payment handling
   - [ ] 3D Secure flow

4. **Stripe Test Cards**
   - [ ] Test successful payment: 4242 4242 4242 4242
   - [ ] Test declined payment: 4000 0000 0000 0002
   - [ ] Test 3D Secure: 4000 0027 6000 3184
   - [ ] Test insufficient funds: 4000 0000 0000 9995

5. **Security Audit**
   - [ ] API key security
   - [ ] Webhook signature verification
   - [ ] Payment amount validation
   - [ ] SQL injection prevention
   - [ ] Rate limiting on payment endpoints

**Deliverables:**
- ✅ 90%+ test coverage
- ✅ All test scenarios passing
- ✅ Security audit complete
- ✅ Bug tracker cleared

---

### **Phase 5: Production Deployment** (Week 5)
**Goal:** Deploy to production with monitoring

#### Tasks
1. **Configuration**
   - [ ] Set production Stripe keys
   - [ ] Configure production webhook URL
   - [ ] Set up environment variables
   - [ ] Database migration to production

2. **Monitoring**
   - [ ] Set up Stripe Dashboard alerts
   - [ ] Configure payment failure notifications
   - [ ] Set up logging for payment events
   - [ ] Create payment metrics dashboard

3. **Documentation**
   - [ ] Update README with payment setup
   - [ ] Create payment troubleshooting guide
   - [ ] Document refund procedures
   - [ ] API documentation complete

4. **Deployment**
   - [ ] Deploy backend changes
   - [ ] Deploy frontend changes
   - [ ] Run database migration
   - [ ] Verify webhook connectivity
   - [ ] Smoke test production

**Deliverables:**
- ✅ Production deployment complete
- ✅ Monitoring in place
- ✅ Documentation updated
- ✅ Go-live checklist signed off

---

## Database Schema

### New Tables

#### `payment_methods` Table
```sql
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    stripe_payment_method_id VARCHAR(255) NOT NULL UNIQUE, -- pm_xxx from Stripe

    -- Card Details (for display only, NOT full card number)
    card_brand VARCHAR(50),           -- 'visa', 'mastercard', 'amex'
    card_last4 VARCHAR(4),             -- Last 4 digits
    card_exp_month INTEGER,            -- 1-12
    card_exp_year INTEGER,             -- YYYY
    card_funding VARCHAR(20),          -- 'credit', 'debit', 'prepaid'

    -- Metadata
    is_default BOOLEAN DEFAULT false,
    billing_name VARCHAR(255),
    billing_email VARCHAR(255),
    billing_address_line1 VARCHAR(255),
    billing_address_line2 VARCHAR(255),
    billing_city VARCHAR(100),
    billing_state VARCHAR(100),
    billing_postal_code VARCHAR(20),
    billing_country VARCHAR(2),        -- ISO 3166-1 alpha-2

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_default_per_customer UNIQUE (customer_id, is_default) WHERE is_default = true
);

CREATE INDEX idx_payment_methods_customer ON payment_methods(customer_id);
CREATE INDEX idx_payment_methods_stripe ON payment_methods(stripe_payment_method_id);

COMMENT ON TABLE payment_methods IS 'Customer saved payment methods (cards) - metadata only, no sensitive data';
COMMENT ON COLUMN payment_methods.stripe_payment_method_id IS 'Stripe PaymentMethod ID (pm_xxx)';
```

#### `payments` Table
```sql
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    payment_method_id INTEGER REFERENCES payment_methods(id) ON DELETE SET NULL,

    -- Stripe References
    stripe_payment_intent_id VARCHAR(255) NOT NULL UNIQUE,  -- pi_xxx
    stripe_charge_id VARCHAR(255),                           -- ch_xxx (after capture)

    -- Amounts (must match order amounts)
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    application_fee DECIMAL(10, 2) DEFAULT 0.00,  -- Platform fee (if applicable)

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'succeeded', 'failed', 'refunded'
    failure_code VARCHAR(100),
    failure_message TEXT,

    -- Metadata
    payment_method_type VARCHAR(50),   -- 'card', 'apple_pay', 'google_pay'
    card_last4 VARCHAR(4),
    card_brand VARCHAR(50),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    captured_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT payments_positive_amount CHECK (amount > 0)
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_stripe_intent ON payments(stripe_payment_intent_id);
CREATE INDEX idx_payments_status ON payments(status);

COMMENT ON TABLE payments IS 'Payment transaction records linked to orders';
COMMENT ON COLUMN payments.stripe_payment_intent_id IS 'Stripe PaymentIntent ID created at order placement';
COMMENT ON COLUMN payments.stripe_charge_id IS 'Stripe Charge ID after payment capture';
```

#### `refunds` Table
```sql
CREATE TABLE IF NOT EXISTS refunds (
    id SERIAL PRIMARY KEY,

    -- Foreign Keys
    payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    refunded_by INTEGER REFERENCES users(id) ON DELETE SET NULL, -- Admin who processed

    -- Stripe Reference
    stripe_refund_id VARCHAR(255) NOT NULL UNIQUE,  -- re_xxx

    -- Amount
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',

    -- Reason
    reason VARCHAR(50),  -- 'requested_by_customer', 'duplicate', 'fraudulent'
    description TEXT,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'succeeded', 'failed'
    failure_reason TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT refunds_positive_amount CHECK (amount > 0)
);

CREATE INDEX idx_refunds_payment ON refunds(payment_id);
CREATE INDEX idx_refunds_order ON refunds(order_id);
CREATE INDEX idx_refunds_stripe ON refunds(stripe_refund_id);

COMMENT ON TABLE refunds IS 'Refund records for cancelled or disputed orders';
```

### Modified Tables

#### Add to `orders` Table
```sql
ALTER TABLE orders
ADD COLUMN payment_status VARCHAR(50) DEFAULT 'pending';
-- Values: 'pending', 'authorized', 'captured', 'failed', 'refunded'

ALTER TABLE orders
ADD COLUMN payment_intent_id VARCHAR(255);

CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_payment_intent ON orders(payment_intent_id);

COMMENT ON COLUMN orders.payment_status IS 'Payment processing status, independent of order status';
COMMENT ON COLUMN orders.payment_intent_id IS 'Stripe PaymentIntent ID for this order';
```

---

## API Endpoints

### Payment Methods Management

#### `POST /api/customer/payment-methods`
**Description:** Save a new payment method (card) to customer's wallet

**Request:**
```json
{
  "stripe_payment_method_id": "pm_1234567890",
  "set_as_default": true,
  "billing_details": {
    "name": "John Doe",
    "email": "john@example.com",
    "address": {
      "line1": "123 Main St",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94111",
      "country": "US"
    }
  }
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "Payment method saved successfully",
  "data": {
    "id": 5,
    "customer_id": 10,
    "stripe_payment_method_id": "pm_1234567890",
    "card_brand": "visa",
    "card_last4": "4242",
    "card_exp_month": 12,
    "card_exp_year": 2025,
    "is_default": true,
    "created_at": "2025-01-03T10:30:00Z"
  }
}
```

#### `GET /api/customer/payment-methods`
**Description:** Get all saved payment methods

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "card_brand": "visa",
      "card_last4": "4242",
      "card_exp_month": 12,
      "card_exp_year": 2025,
      "is_default": true
    }
  ]
}
```

#### `DELETE /api/customer/payment-methods/:id`
**Description:** Remove a saved payment method

**Response:** `200 OK`

---

### Order Payment Flow

#### `POST /api/customer/orders`
**Description:** Create order and payment intent (MODIFIED)

**Request:**
```json
{
  "restaurant_id": 1,
  "delivery_address_id": 5,
  "items": [
    {
      "menu_item_id": "item_123",
      "quantity": 2,
      "customizations": {...}
    }
  ],
  "payment_method_id": 5,  // NEW: Optional saved card
  "special_instructions": "Ring doorbell"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "message": "Order created, payment required",
  "data": {
    "order_id": 123,
    "total_amount": 45.99,
    "payment_intent": {
      "id": "pi_1234567890",
      "client_secret": "pi_1234567890_secret_abcdef",
      "status": "requires_payment_method"
    }
  }
}
```

#### `PUT /api/customer/orders/:id/confirm-payment`
**Description:** Confirm payment after Stripe client-side confirmation

**Request:**
```json
{
  "payment_intent_id": "pi_1234567890"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Payment confirmed, order placed",
  "data": {
    "order_id": 123,
    "payment_status": "succeeded",
    "order_status": "pending"
  }
}
```

---

### Refunds (Admin)

#### `POST /api/admin/orders/:id/refund`
**Description:** Process refund for cancelled order

**Request:**
```json
{
  "reason": "requested_by_customer",
  "description": "Customer changed mind",
  "amount": 45.99  // Optional: partial refund
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Refund processed successfully",
  "data": {
    "refund_id": 10,
    "stripe_refund_id": "re_1234567890",
    "amount": 45.99,
    "status": "succeeded"
  }
}
```

---

### Webhooks

#### `POST /api/webhooks/stripe`
**Description:** Receive Stripe webhook events

**Headers:**
```
Stripe-Signature: t=1234567890,v1=abc123...
```

**Events Handled:**
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refunded`
- `payment_method.attached`
- `payment_method.detached`

**Response:** `200 OK`
```json
{
  "received": true
}
```

---

## Security Considerations

### PCI Compliance
✅ **Card data never touches our servers**
- Stripe handles all card input via Stripe.js/Flutter SDK
- We only store Stripe IDs (pm_xxx, pi_xxx, ch_xxx)
- Card display uses last4 + brand only

### API Key Management
```env
# Development (.env)
STRIPE_SECRET_KEY=sk_test_xxxxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxx

# Production (.env.production)
STRIPE_SECRET_KEY=sk_live_xxxxx  # ⚠️ NEVER commit to git
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxx
```

### Webhook Signature Verification
```go
func VerifyStripeWebhook(body []byte, signature string) (stripe.Event, error) {
    event, err := webhook.ConstructEvent(
        body,
        signature,
        os.Getenv("STRIPE_WEBHOOK_SECRET"),
    )
    if err != nil {
        return event, fmt.Errorf("webhook signature verification failed: %w", err)
    }
    return event, nil
}
```

### Payment Amount Validation
```go
// CRITICAL: Verify payment intent amount matches order total
func ValidatePaymentAmount(order *Order, paymentIntent *stripe.PaymentIntent) error {
    expectedAmount := int64(order.TotalAmount * 100) // Convert to cents
    if paymentIntent.Amount != expectedAmount {
        return fmt.Errorf(
            "payment amount mismatch: expected %d, got %d",
            expectedAmount,
            paymentIntent.Amount,
        )
    }
    return nil
}
```

### Rate Limiting
```go
// Limit payment attempts per customer
var paymentRateLimiter = rate.NewLimiter(
    rate.Limit(10),  // 10 attempts
    rate.Every(time.Hour), // per hour
)
```

---

## Testing Strategy

### Test Environments
1. **Local Development:** Stripe Test Mode
2. **Staging:** Stripe Test Mode
3. **Production:** Stripe Live Mode

### Stripe Test Cards
| Scenario | Card Number | Result |
|----------|-------------|---------|
| Success | 4242 4242 4242 4242 | Payment succeeds |
| Decline | 4000 0000 0000 0002 | Card declined |
| 3D Secure | 4000 0027 6000 3184 | Requires authentication |
| Insufficient Funds | 4000 0000 0000 9995 | Insufficient funds |
| Expired Card | 4000 0000 0000 0069 | Expired card |

### Test Scenarios

#### Happy Path
1. Customer adds items to cart
2. Customer proceeds to checkout
3. Customer selects saved card (or enters new card)
4. Payment succeeds
5. Order confirmed to vendor
6. Email confirmation sent

#### Failed Payment
1. Customer uses declined card
2. Payment fails
3. Order not created (or remains in 'pending_payment')
4. User shown error message
5. User can retry with different card

#### Refund Flow
1. Customer cancels order
2. Admin processes refund
3. Refund succeeds
4. Order status → 'refunded'
5. Customer receives refund confirmation

---

## Deployment Plan

### Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Security audit complete
- [ ] Stripe production keys configured
- [ ] Webhook URL configured in Stripe Dashboard
- [ ] Database migration tested
- [ ] Rollback plan ready

### Deployment Steps
1. **Database Migration**
   ```bash
   # Run migration on production
   psql $DATABASE_URL -f backend/sql/migrations/008_add_stripe_payments.sql
   ```

2. **Backend Deployment**
   ```bash
   # Build and deploy Go backend
   cd backend
   go build -o delivery_app
   # Deploy to server
   ```

3. **Frontend Deployment**
   ```bash
   # Build Flutter web app
   cd frontend
   flutter build web --release
   # Deploy to hosting
   ```

4. **Verify Webhook**
   ```bash
   # Test webhook connectivity
   stripe listen --forward-to https://api.yourapp.com/webhooks/stripe
   ```

5. **Smoke Test**
   - [ ] Create test order
   - [ ] Process payment
   - [ ] Verify webhook received
   - [ ] Check database records

### Rollback Plan
If critical issues occur:
1. Revert backend deployment
2. Keep database schema (no data loss)
3. Disable payment features via feature flag
4. Investigate and fix issues
5. Re-deploy

---

## Future Enhancements

### Phase 6: Advanced Features
- [ ] Apple Pay integration
- [ ] Google Pay integration
- [ ] Subscription support (for vendors)
- [ ] Multi-currency support
- [ ] Split payments (multiple cards)
- [ ] Tipping for drivers
- [ ] Promo codes and discounts
- [ ] Payment analytics dashboard

### Phase 7: Optimization
- [ ] Automatic retry for failed payments
- [ ] Smart routing for best payment success rates
- [ ] Fraud detection with Stripe Radar
- [ ] Payment method recommendations
- [ ] A/B testing for payment UI

---

## Appendix

### Stripe Resources
- **API Docs:** https://stripe.com/docs/api
- **Payment Intents Guide:** https://stripe.com/docs/payments/payment-intents
- **Flutter SDK:** https://pub.dev/packages/flutter_stripe
- **Go SDK:** https://github.com/stripe/stripe-go

### Support Contacts
- **Stripe Support:** support@stripe.com
- **Stripe Dashboard:** https://dashboard.stripe.com

### Cost Estimates
- **Stripe Fees:** 2.9% + $0.30 per successful transaction
- **Monthly Volume (estimate):** 1,000 orders @ avg $30 = $30,000
- **Monthly Fees:** ~$1,170 (2.9% + $0.30)

---

**End of Document**
**Next Steps:** Review and approval, then begin Phase 1 implementation
