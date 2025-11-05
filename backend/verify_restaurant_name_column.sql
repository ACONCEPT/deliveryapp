-- SQL script to verify restaurant_name column exists and has data

-- 1. Check if restaurant_name column exists in orders table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name = 'restaurant_name';

-- 2. Count orders with and without restaurant_name
SELECT
    COUNT(*) as total_orders,
    COUNT(restaurant_name) as orders_with_name,
    COUNT(*) - COUNT(restaurant_name) as orders_without_name
FROM orders;

-- 3. Sample orders showing restaurant_name
SELECT
    id,
    customer_id,
    restaurant_id,
    restaurant_name,
    status,
    total_amount,
    created_at
FROM orders
ORDER BY created_at DESC
LIMIT 10;

-- 4. Compare restaurant_name in orders vs restaurants table (verify sync)
SELECT
    o.id as order_id,
    o.restaurant_id,
    o.restaurant_name as order_restaurant_name,
    r.name as current_restaurant_name,
    CASE
        WHEN o.restaurant_name = r.name THEN 'MATCH'
        ELSE 'MISMATCH'
    END as comparison
FROM orders o
LEFT JOIN restaurants r ON o.restaurant_id = r.id
LIMIT 20;

-- 5. Performance test: Query with and without JOIN
-- This is for manual EXPLAIN ANALYZE comparison

-- Query WITHOUT JOIN (optimized)
-- EXPLAIN ANALYZE
-- SELECT id, customer_id, restaurant_id, restaurant_name, status, total_amount
-- FROM orders
-- WHERE customer_id = 1
-- ORDER BY created_at DESC
-- LIMIT 20;

-- Query WITH JOIN (old way - for comparison only)
-- EXPLAIN ANALYZE
-- SELECT o.id, o.customer_id, o.restaurant_id, r.name as restaurant_name, o.status, o.total_amount
-- FROM orders o
-- LEFT JOIN restaurants r ON o.restaurant_id = r.id
-- WHERE o.customer_id = 1
-- ORDER BY o.created_at DESC
-- LIMIT 20;

-- 6. Index verification
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'orders'
ORDER BY indexname;
