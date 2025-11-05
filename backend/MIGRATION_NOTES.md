# Migration Notes - Schema Consolidation

## Current Production Database State

Before running fresh migrations, the production database had:
- 3 restaurants: Pizza Palace, Burger Haven, China Garden
- Migration 006 already applied (TIMESTAMPTZ conversion done)
- Timezone columns already added to restaurants and customer_addresses
- customer1 address already existed (29959 Overseas Highway, Big Pine Key)

## Fresh Install State (After Consolidation)

After running `./tools/sh/setup-database.sh` with consolidated schema:
- 1 restaurant: China Garden only
- All TIMESTAMPTZ columns properly configured
- Timezone columns included in schema
- customer1 address seeded with timezone

## For Existing Production Instances

### If You Want to Keep All 3 Restaurants:
No action needed! Your existing database is fine. The schema consolidation:
- ✅ Already has TIMESTAMPTZ (migration 006 was applied)
- ✅ Already has timezone columns
- ✅ Has all your existing restaurants and data

The consolidated schema.sql is primarily for **fresh installations** going forward.

### If You Want to Match the New Seed Data:
Only if you want to remove Pizza Palace and Burger Haven:

```sql
-- WARNING: This will delete restaurants and associated data!
BEGIN;

-- Remove restaurant-menu associations
DELETE FROM restaurant_menus 
WHERE restaurant_id IN (
  SELECT id FROM restaurants 
  WHERE name IN ('Pizza Palace', 'Burger Haven')
);

-- Remove vendor-restaurant associations  
DELETE FROM vendor_restaurants 
WHERE restaurant_id IN (
  SELECT id FROM restaurants 
  WHERE name IN ('Pizza Palace', 'Burger Haven')
);

-- Remove menus (if not used elsewhere)
DELETE FROM menus 
WHERE name IN ('Pizza Palace Main Menu', 'Burger Haven Main Menu');

-- Remove restaurants
DELETE FROM restaurants 
WHERE name IN ('Pizza Palace', 'Burger Haven');

-- Verify only China Garden remains
SELECT id, name, city, timezone FROM restaurants;

COMMIT; -- or ROLLBACK if you change your mind
```

## Recommendation

**For production**: Keep your existing database as-is. It's already up to date with migration 006.

**For new developers**: Use `./tools/sh/setup-database.sh` which will create a clean database with only China Garden.

## Files Changed in This Consolidation

1. **backend/sql/schema.sql**
   - All TIMESTAMP → TIMESTAMPTZ
   - Timezone columns added
   - Seed data updated to China Garden only
   - customer1 address seed data added

2. **backend/sql/migrations/006_convert_to_timestamptz.sql**
   - Moved to `archived/` directory
   - Fully integrated into schema.sql

3. **New files**:
   - `SCHEMA_CONSOLIDATION_SUMMARY.md` - Detailed change log
   - `MIGRATION_NOTES.md` - This file
   - `verify_consolidated_schema.sh` - Verification script
