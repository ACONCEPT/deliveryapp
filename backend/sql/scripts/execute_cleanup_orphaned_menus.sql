-- Execute Orphaned Menus Cleanup
-- This script permanently deletes orphaned menus
-- Run after reviewing results from cleanup_orphaned_menus.sql

-- Start transaction
BEGIN;

-- Create temporary table to track what we're deleting
CREATE TEMP TABLE menus_to_delete AS
SELECT
    m.id,
    m.name,
    m.vendor_id,
    v.business_name AS vendor_name,
    m.created_at
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
LEFT JOIN vendors v ON m.vendor_id = v.id
WHERE rm.menu_id IS NULL;

-- Display summary before deletion
\echo '================================================'
\echo 'DELETION SUMMARY - REVIEW BEFORE COMMITTING'
\echo '================================================'

SELECT
    COUNT(*) AS menus_to_delete,
    STRING_AGG(DISTINCT COALESCE(vendor_name, 'NO VENDOR'), ', ' ORDER BY COALESCE(vendor_name, 'NO VENDOR')) AS affected_vendors
FROM menus_to_delete;

-- Display details of menus being deleted
\echo ''
\echo 'Menus to be deleted:'
\echo '-------------------'

SELECT
    id,
    name,
    COALESCE(vendor_name, 'NO VENDOR') AS vendor,
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') AS created
FROM menus_to_delete
ORDER BY created_at DESC;

-- Execute the deletion
DELETE FROM menus
WHERE id IN (SELECT id FROM menus_to_delete);

-- Display results
\echo ''
\echo 'Deletion completed!'
\echo '-------------------'

SELECT
    (SELECT COUNT(*) FROM menus_to_delete) AS deleted_count,
    (SELECT COUNT(*) FROM menus) AS remaining_menus,
    (SELECT COUNT(*) FROM restaurant_menus) AS remaining_assignments;

-- Verify no orphaned menus remain
\echo ''
\echo 'Verification:'
\echo '-------------'

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ SUCCESS: All orphaned menus have been removed'
        ELSE '✗ ERROR: ' || COUNT(*) || ' orphaned menus still exist'
    END AS verification_status
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
WHERE rm.menu_id IS NULL;

-- Clean up temp table
DROP TABLE IF EXISTS menus_to_delete;

-- Commit the transaction
COMMIT;

\echo ''
\echo '✓ Transaction committed successfully'
\echo 'Orphaned menus have been permanently deleted'
