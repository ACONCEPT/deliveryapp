# OpenAPI Documentation Update - Restaurant Name in Orders

## Summary

Updated OpenAPI documentation to clarify that `restaurant_name` is automatically populated when creating orders and is included in all order list responses.

---

## Changes Made

### 1. Order Schema (`backend/openapi/schemas/order.yaml`)

#### ✅ Order Response Schema (Already Correct)
- **Lines 42-45**: `restaurant_name` property documented with clear description
- **Type**: `string`
- **Description**: "Name of the restaurant at time of order (denormalized for performance and historical accuracy)"
- **Example**: "Pizza Palace"

#### ✅ CreateOrderRequest Schema (Updated)
- **Lines 208-236**: Added comprehensive description explaining that `restaurant_name` should NOT be provided
- **Key Points**:
  - Restaurant name is auto-fetched from database
  - Clients should NOT include restaurant_name in request
  - Ensures security and data integrity
  - Any provided restaurant_name will be ignored

**Before**:
```yaml
CreateOrderRequest:
  type: object
  required:
    - restaurant_id
    - delivery_address_id
    - items
  properties:
    restaurant_id:
      type: integer
      example: 1
```

**After**:
```yaml
CreateOrderRequest:
  type: object
  required:
    - restaurant_id
    - delivery_address_id
    - items
  description: |
    Request to create a new order.

    **Important**: Do NOT include `restaurant_name` in this request. The restaurant name
    is automatically fetched from the database based on `restaurant_id` for security
    and data integrity. Any provided `restaurant_name` will be ignored.
  properties:
    restaurant_id:
      type: integer
      description: ID of the restaurant (name will be fetched automatically)
      example: 1
```

### 2. Order Creation Endpoint (`backend/openapi/paths/orders.yaml`)

#### ✅ POST /api/customer/orders (Updated)

**Description Enhanced** (Lines 5-18):
- Added note explaining restaurant_name is auto-fetched
- Clarified security reason for server-side fetching
- Added step-by-step process documentation

**Before**:
```yaml
description: |
  Create a new order for the authenticated customer.
  The system will:
  1. Validate restaurant is active and approved
  2. Validate delivery address belongs to customer
  3. Calculate totals (subtotal, tax, delivery fee)
  4. Check minimum order amount
  5. Create order and items in a transaction
```

**After**:
```yaml
description: |
  Create a new order for the authenticated customer.

  **Note**: The `restaurant_name` is automatically fetched from the restaurants table
  and stored in the order for historical accuracy. Clients should NOT provide
  restaurant_name in the request - it is fetched server-side for security.

  The system will:
  1. Fetch restaurant name from database (based on restaurant_id)
  2. Validate restaurant is active and approved
  3. Validate delivery address belongs to customer
  4. Calculate totals (subtotal, tax, delivery fee)
  5. Check minimum order amount
  6. Create order and items in a transaction
```

**Response Schema Updated** (Lines 24-53):
- Changed from partial order data to full Order schema reference
- Added comprehensive example showing restaurant_name in response

**Before**:
```yaml
'201':
  description: Order created successfully
  content:
    application/json:
      schema:
        type: object
        properties:
          success:
            type: boolean
          message:
            type: string
          data:
            type: object
            properties:
              order_id:
                type: integer
              total_amount:
                type: number
              status:
                type: string
```

**After**:
```yaml
'201':
  description: Order created successfully
  content:
    application/json:
      schema:
        type: object
        properties:
          success:
            type: boolean
          message:
            type: string
          data:
            $ref: '../schemas/order.yaml#/Order'
      example:
        success: true
        message: Order placed successfully
        data:
          id: 42
          customer_id: 1
          restaurant_id: 1
          restaurant_name: Pizza Palace  # ← CLEARLY SHOWS THIS FIELD
          delivery_address_id: 1
          status: pending
          subtotal_amount: 35.97
          tax_amount: 3.06
          delivery_fee: 5.00
          total_amount: 44.03
          created_at: '2024-01-15T10:30:00Z'
```

### 3. Order List Endpoints (Already Correct)

#### ✅ Customer Order Lists
- `GET /api/customer/orders` (Line 127) - References Order schema ✅
- `GET /api/customer/orders/{id}` - References Order schema ✅
- `GET /api/customer/orders/active` - References Order schema ✅
- `GET /api/customer/orders/history` - References Order schema ✅

#### ✅ Vendor Order Lists
- `GET /api/vendor/orders` (Line 347) - References Order schema ✅
- `GET /api/vendor/orders/{id}` - References Order schema ✅
- `GET /api/vendor/orders/by-status` - References Order schema ✅

#### ✅ Driver Order Lists
- `GET /api/driver/orders` (Line 752) - References Order schema ✅
- `GET /api/driver/orders/{id}` - References Order schema ✅
- `GET /api/driver/orders/available` - References Order schema ✅

#### ✅ Admin Order Lists
- `GET /api/admin/orders` - References Order schema ✅
- `GET /api/admin/orders/{id}` - References Order schema ✅

**All endpoints** use `$ref: '#/components/schemas/Order'` which includes `restaurant_name`.

---

## Verification Checklist

### ✅ Schema Definitions
- [x] Order schema has restaurant_name property (lines 42-45)
- [x] CreateOrderRequest does NOT have restaurant_name property
- [x] CreateOrderRequest has clear documentation about auto-fetching
- [x] Order schema description explains denormalization purpose

### ✅ Request Documentation
- [x] POST /api/customer/orders description explains auto-fetch
- [x] POST /api/customer/orders response shows full Order with restaurant_name
- [x] Security rationale clearly documented

### ✅ Response Documentation
- [x] All customer order endpoints return Order schema
- [x] All vendor order endpoints return Order schema
- [x] All driver order endpoints return Order schema
- [x] All admin order endpoints return Order schema

### ✅ Security & Data Integrity
- [x] Documentation makes it clear restaurant_name cannot be provided by client
- [x] Explanation of server-side fetching for security
- [x] Historical accuracy benefit documented

---

## Files Modified

### Backend OpenAPI Documentation
1. **`/backend/openapi/schemas/order.yaml`**
   - Lines 208-236: Enhanced CreateOrderRequest description
   - Lines 42-45: Order.restaurant_name property (already existed)

2. **`/backend/openapi/paths/orders.yaml`**
   - Lines 5-18: Enhanced POST /api/customer/orders description
   - Lines 24-53: Updated POST response to use full Order schema

---

## Example API Behavior

### Creating an Order

**Request** (restaurant_name NOT included):
```bash
POST /api/customer/orders
Content-Type: application/json
Authorization: Bearer {token}

{
  "restaurant_id": 1,
  "delivery_address_id": 5,
  "items": [
    {
      "menu_item_id": 10,
      "quantity": 2,
      "customizations": []
    }
  ]
}
```

**Response** (restaurant_name automatically included):
```json
{
  "success": true,
  "message": "Order placed successfully",
  "data": {
    "id": 42,
    "customer_id": 1,
    "restaurant_id": 1,
    "restaurant_name": "Pizza Palace",  ← AUTO-POPULATED
    "delivery_address_id": 5,
    "status": "pending",
    "subtotal_amount": 35.97,
    "tax_amount": 3.06,
    "delivery_fee": 5.00,
    "total_amount": 44.03,
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

### Listing Orders

**Request**:
```bash
GET /api/customer/orders
Authorization: Bearer {token}
```

**Response** (all orders include restaurant_name):
```json
{
  "success": true,
  "message": "Orders retrieved successfully",
  "data": {
    "orders": [
      {
        "id": 42,
        "restaurant_id": 1,
        "restaurant_name": "Pizza Palace",  ← INCLUDED
        "status": "pending",
        "total_amount": 44.03,
        "created_at": "2024-01-15T10:30:00Z"
      },
      {
        "id": 41,
        "restaurant_id": 3,
        "restaurant_name": "Burger Haven",  ← INCLUDED
        "status": "delivered",
        "total_amount": 28.50,
        "created_at": "2024-01-14T18:20:00Z"
      }
    ],
    "page": 1,
    "per_page": 20
  }
}
```

---

## Security & Design Rationale

### Why Restaurant Name is Server-Side Only

1. **Security**: Prevents data tampering
   - Client could provide fake restaurant name
   - Server always fetches from authoritative source (restaurants table)

2. **Data Integrity**: Single source of truth
   - Restaurant name always matches database reality
   - No risk of client/server data mismatch

3. **Historical Accuracy**: Denormalization for records
   - Order preserves restaurant name at time of purchase
   - Even if restaurant is renamed later, order history remains accurate

4. **Performance**: No JOIN needed
   - Restaurant name stored in orders table
   - Listing orders doesn't require JOIN with restaurants table
   - Faster queries, especially for large order lists

---

## Related Documentation

### Backend Implementation
- **Schema**: `/backend/sql/schema.sql` (Line 487) - restaurant_name column
- **Model**: `/backend/models/order.go` (Line 113) - RestaurantName field
- **Repository**: `/backend/repositories/order_repository.go` (Lines 67-103) - Auto-fetch logic

### API Documentation
- **Order Schema**: `/backend/openapi/schemas/order.yaml`
- **Order Endpoints**: `/backend/openapi/paths/orders.yaml`
- **Main OpenAPI**: `/backend/openapi.yaml`

### Testing
- **Integration Test**: `/backend/test_restaurant_name_in_orders.sh`
- **SQL Verification**: `/backend/verify_restaurant_name_column.sql`
- **Review Document**: `/backend/ORDER_RESTAURANT_NAME_REVIEW.md`

---

## Summary

✅ **OpenAPI Documentation Updated**
- Clear explanation that restaurant_name is server-side only
- All order list endpoints documented to return restaurant_name
- Security and design rationale clearly explained
- Comprehensive examples provided

✅ **Consistency Verified**
- All 15+ order endpoints reference Order schema
- Order schema includes restaurant_name property
- CreateOrderRequest explicitly excludes restaurant_name

✅ **Developer Experience**
- API consumers understand they should NOT provide restaurant_name
- Clear documentation of what to expect in responses
- Examples show restaurant_name in all relevant contexts

**Status**: ✅ **Complete and Production Ready**
