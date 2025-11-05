# Database Schema Consolidation Summary

**Date**: 2025-10-30  
**Migration Consolidated**: 006_convert_to_timestamptz.sql

## Changes Made

### 1. TIMESTAMP to TIMESTAMPTZ Conversion

All `TIMESTAMP` columns across the entire database have been converted to `TIMESTAMPTZ` (timestamp with time zone):

#### Affected Tables and Columns:
- **users**: `created_at`, `updated_at`
- **customers**: `created_at`, `updated_at`
- **customer_addresses**: `created_at`, `updated_at`
- **vendors**: `approved_at`, `created_at`, `updated_at`
- **vendor_users**: `created_at`, `updated_at`
- **restaurants**: `approved_at`, `created_at`, `updated_at`
- **menus**: `created_at`, `updated_at`
- **restaurant_menus**: `created_at`, `updated_at`
- **vendor_restaurants**: `created_at`, `updated_at`
- **drivers**: `approved_at`, `created_at`, `updated_at`
- **admins**: `created_at`, `updated_at`
- **approval_history**: `created_at`
- **orders**: `created_at`, `placed_at`, `confirmed_at`, `ready_at`, `delivered_at`, `cancelled_at`, `estimated_delivery_time`, `updated_at`
- **order_items**: `created_at`, `updated_at`
- **order_status_history**: `created_at`
- **system_settings**: `created_at`, `updated_at`
- **dashboard_widgets**: `created_at`, `updated_at`
- **user_role_widgets**: `created_at`, `updated_at`
- **messages**: `read_at`, `created_at`, `updated_at`
- **distance_requests**: `created_at`

### 2. Timezone Column Additions

#### restaurants table:
- Added `timezone VARCHAR(50) DEFAULT 'UTC' NOT NULL`
- IANA timezone identifier (e.g., 'America/New_York', 'America/Los_Angeles')
- All order timestamps use the restaurant's timezone for display
- Index added: `idx_restaurants_timezone`

#### customer_addresses table:
- Added `timezone VARCHAR(50)` (nullable)
- IANA timezone identifier for delivery address location
- Optional field that can differ from restaurant timezone
- Index added: `idx_customer_addresses_timezone`

### 3. Seed Data Updates

#### Restaurants - REMOVED:
- ❌ Pizza Palace (New York, NY)
- ❌ Burger Haven (New York, NY)

#### Restaurants - KEPT/ADDED:
- ✅ **China Garden** (Big Pine Key, Florida)
  - Address: 209 Key Deer Boulevard
  - Timezone: America/New_York (Eastern Time)
  - Hours: Mon-Thu & Sun 11:00-21:00, Fri-Sat 11:00-22:00
  - Phone: +1305872222

#### Menus - REMOVED:
- ❌ Pizza Palace Main Menu
- ❌ Burger Haven Main Menu

#### Menus - KEPT/ADDED:
- ✅ **China Garden Main Menu**
  - Categories: Appetizers, Entrees, Rice & Noodles
  - Items include: Spring Rolls, Dumplings, General Tso Chicken, Beef with Broccoli, Lo Mein, Fried Rice, Chow Mein

#### Customer Addresses - ADDED:
- ✅ **customer1 default address**
  - Address: 29959 Overseas Highway, Big Pine Key, Florida 33043
  - Timezone: America/New_York (Eastern Time)
  - Set as default address

### 4. Function Updates

#### update_updated_at_column()
- Updated to explicitly use UTC: `CURRENT_TIMESTAMP AT TIME ZONE 'UTC'`
- Added comment: 'Automatically sets updated_at to current UTC timestamp when a row is modified'

### 5. Schema Header Update

Updated header comments to include:
- Migration 006 in the consolidated migrations list
- Last updated date changed to 2025-10-30
- Seed data documentation

### 6. Migration Archive

- Moved `006_convert_to_timestamptz.sql` to `backend/sql/migrations/archived/`
- This migration is now fully integrated into `schema.sql`

## Database Integrity Verification

All relationships verified as intact:
- ✅ 1 restaurant (China Garden)
- ✅ 1 restaurant with vendor ownership (vendor1 → China Garden)
- ✅ 1 restaurant with menu assignment (China Garden → China Garden Main Menu)
- ✅ 1 menu in database
- ✅ 1 customer address
- ✅ All TIMESTAMPTZ columns created correctly
- ✅ All timezone columns created correctly
- ✅ All indexes created successfully

## Files Modified

### Primary Changes:
- `/backend/sql/schema.sql` - Main schema file with all consolidations
  - All TIMESTAMP → TIMESTAMPTZ conversions
  - Added timezone columns to restaurants and customer_addresses
  - Updated seed data to only include China Garden
  - Added customer1 address seed data
  - Updated update_updated_at_column() function
  - Added timezone column indexes
  - Updated header and completion notices

### Archived:
- `/backend/sql/migrations/006_convert_to_timestamptz.sql` → `/backend/sql/migrations/archived/`

## Testing Performed

```bash
# Fresh database setup
./tools/sh/setup-database.sh

# Verified restaurant data
psql $DATABASE_URL -c "SELECT id, name, city, timezone FROM restaurants;"

# Verified customer addresses
psql $DATABASE_URL -c "SELECT id, address_line1, city, timezone FROM customer_addresses;"

# Verified TIMESTAMPTZ columns
psql $DATABASE_URL -c "SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name IN ('restaurants', 'customer_addresses', 'orders') 
AND column_name LIKE '%at' OR column_name = 'timezone';"

# Verified relationships
psql $DATABASE_URL -c "SELECT v.business_name, r.name FROM vendor_restaurants vr 
JOIN vendors v ON vr.vendor_id = v.id 
JOIN restaurants r ON vr.restaurant_id = r.id;"
```

All tests passed successfully ✅

## Deployment Notes

### For Fresh Installs:
Simply run `./tools/sh/setup-database.sh` - the consolidated schema.sql includes everything.

### For Existing Production Databases:
If migration 006 has NOT been applied yet:
1. Apply the archived migration: `psql $DATABASE_URL -f backend/sql/migrations/archived/006_convert_to_timestamptz.sql`
2. Manually remove Pizza Palace and Burger Haven if they exist (optional)
3. Manually add China Garden and customer address if desired (optional)

If migration 006 has ALREADY been applied:
- No action needed for timestamp columns
- Manually update seed data if desired
- The schema.sql is now consistent with your database state

## Breaking Changes

None. This consolidation:
- Maintains backward compatibility for existing data
- All existing timestamps are preserved (assumed to be UTC)
- New timezone columns are nullable or have defaults

## Next Steps

1. ✅ Schema consolidation complete
2. ⏭️ Consider updating Go models if they reference specific restaurants by name
3. ⏭️ Frontend may need updates if it hardcoded restaurant names
4. ⏭️ Update any integration tests that reference Pizza Palace or Burger Haven
5. ⏭️ Consider adding more Chinese food items to the menu if needed

## Timezone Information

**Big Pine Key, Florida**:
- Timezone: America/New_York (Eastern Time Zone)
- UTC Offset: UTC-5 (EST) / UTC-4 (EDT during daylight saving)
- Same timezone as New York City, Miami, and the Florida Keys

All timestamps in the database are stored in UTC (TIMESTAMPTZ automatically handles this), but the timezone fields allow the application to display times in the appropriate local timezone for the restaurant or delivery address.
