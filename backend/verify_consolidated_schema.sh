#!/bin/bash
# Verification script for consolidated schema
# Run this to verify the database matches expected state after consolidation

set -e

DATABASE_URL="${DATABASE_URL:-postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable}"

echo "========================================="
echo "Schema Consolidation Verification"
echo "========================================="
echo ""

echo "1. Verifying restaurant count and timezone..."
psql "$DATABASE_URL" -c "SELECT COUNT(*) as total_restaurants, 
       COUNT(CASE WHEN name = 'China Garden' THEN 1 END) as china_garden_count,
       COUNT(CASE WHEN timezone = 'America/New_York' THEN 1 END) as tz_america_ny
FROM restaurants;" -t

echo ""
echo "2. Verifying restaurant details..."
psql "$DATABASE_URL" -c "SELECT id, name, city, state, timezone, approval_status 
FROM restaurants ORDER BY id;"

echo ""
echo "3. Verifying customer address..."
psql "$DATABASE_URL" -c "SELECT id, address_line1, city, timezone, is_default 
FROM customer_addresses ORDER BY id;"

echo ""
echo "4. Verifying menu associations..."
psql "$DATABASE_URL" -c "SELECT m.id, m.name, r.name as restaurant 
FROM menus m 
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id 
LEFT JOIN restaurants r ON rm.restaurant_id = r.id 
ORDER BY m.id;"

echo ""
echo "5. Verifying vendor-restaurant relationships..."
psql "$DATABASE_URL" -c "SELECT vr.id, v.business_name as vendor, r.name as restaurant 
FROM vendor_restaurants vr 
JOIN vendors v ON vr.vendor_id = v.id 
JOIN restaurants r ON vr.restaurant_id = r.id 
ORDER BY vr.id;"

echo ""
echo "6. Verifying TIMESTAMPTZ columns in key tables..."
echo "   Restaurants table:"
psql "$DATABASE_URL" -c "SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'restaurants' 
AND column_name IN ('created_at', 'updated_at', 'approved_at', 'timezone') 
ORDER BY column_name;" -t

echo ""
echo "   Customer addresses table:"
psql "$DATABASE_URL" -c "SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'customer_addresses' 
AND column_name IN ('created_at', 'updated_at', 'timezone') 
ORDER BY column_name;" -t

echo ""
echo "   Orders table (sample):"
psql "$DATABASE_URL" -c "SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND column_name IN ('created_at', 'placed_at', 'confirmed_at', 'delivered_at') 
ORDER BY column_name;" -t

echo ""
echo "7. Verifying timezone indexes..."
psql "$DATABASE_URL" -c "SELECT indexname 
FROM pg_indexes 
WHERE tablename IN ('restaurants', 'customer_addresses') 
AND indexname LIKE '%timezone%' 
ORDER BY indexname;"

echo ""
echo "8. Database statistics..."
psql "$DATABASE_URL" -c "SELECT 
    (SELECT COUNT(*) FROM restaurants) as restaurants,
    (SELECT COUNT(*) FROM menus) as menus,
    (SELECT COUNT(*) FROM customer_addresses) as addresses,
    (SELECT COUNT(*) FROM vendor_restaurants) as vendor_restaurant_links,
    (SELECT COUNT(*) FROM restaurant_menus) as restaurant_menu_links;" -t

echo ""
echo "========================================="
echo "✅ Verification Complete"
echo "========================================="
echo ""
echo "Expected state:"
echo "  - 1 restaurant (China Garden)"
echo "  - 1 menu (China Garden Main Menu)"
echo "  - 1 customer address"
echo "  - All timestamps should be 'timestamp with time zone'"
echo "  - Timezone columns should be 'character varying'"
echo ""
