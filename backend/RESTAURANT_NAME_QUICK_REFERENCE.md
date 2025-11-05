# Restaurant Name Field - Quick Reference

## What Changed?

Added `restaurant_name VARCHAR(255) NOT NULL` to the `orders` table.

## Why?

1. **Performance**: No JOIN needed when displaying orders
2. **History**: Preserves restaurant name even if restaurant is renamed/deleted
3. **Simplicity**: Cleaner queries

## Files Modified

| File | Change |
|------|--------|
| `sql/schema.sql` | Added `restaurant_name VARCHAR(255) NOT NULL` column |
| `models/order.go` | Added `RestaurantName string` field to Order struct |
| `repositories/order_repository.go` | Auto-fetch restaurant name on order creation |
| `openapi/schemas/order.yaml` | Added `restaurant_name` to Order schema |

## Fresh Install (Development)

```bash
./tools/sh/setup-database.sh
```

Done! The schema includes the new column.

## Production Migration

```bash
psql $DATABASE_URL -f backend/sql/migrations/007_add_restaurant_name_to_orders.sql
```

This will:
1. Add column (nullable)
2. Backfill from restaurants table
3. Make NOT NULL
4. Add comment

## Verify Installation

```bash
# Check column exists
psql $DATABASE_URL -c "\d orders" | grep restaurant_name

# Expected output:
# restaurant_name | character varying(255) | | not null |
```

## API Response Example

**Before**:
```json
{
  "id": 1,
  "restaurant_id": 1,
  "status": "pending",
  "total_amount": 25.99
}
```

**After**:
```json
{
  "id": 1,
  "restaurant_id": 1,
  "restaurant_name": "Pizza Palace",  // NEW!
  "status": "pending",
  "total_amount": 25.99
}
```

## How It Works

When creating an order:

1. Repository checks if `order.RestaurantName` is empty
2. If empty, fetches from `restaurants.name` WHERE `id = order.RestaurantID`
3. Stores the name in the order
4. Name is frozen forever (preserves history)

## Testing

```bash
# Build backend
cd backend && go build -o delivery_app main.go middleware.go

# Start backend
./delivery_app

# Run automated test (in another terminal)
./test_restaurant_name_feature.sh
```

## Important Notes

⚠️ **Historical Preservation**
- Name is stored at order creation time
- Does NOT update if restaurant is renamed
- This is intentional (historical accuracy)

✅ **Data Source**
- Always fetched from restaurants table
- Client cannot override (security)

❌ **No Cascade Updates**
- Do NOT add triggers to update on restaurant rename
- Would break historical record

## Rollback (Emergency Only)

```sql
ALTER TABLE orders DROP COLUMN restaurant_name;
```

## Full Documentation

See `RESTAURANT_NAME_IMPLEMENTATION.md` for complete details.
