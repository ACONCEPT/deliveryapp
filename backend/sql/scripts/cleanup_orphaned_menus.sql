-- Cleanup Orphaned Menus Script
-- Purpose: Identifies and removes menus that have no restaurant associations
-- Author: Claude Code
-- Date: 2025-10-27
--
-- CAUTION: This script permanently deletes data. Review results before executing DELETE section.
--
-- What are orphaned menus?
-- Menus that exist in the 'menus' table but have no entries in the 'restaurant_menus' junction table.
-- This can happen when:
-- 1. Menus are created but never assigned to restaurants
-- 2. All restaurant associations are deleted but the menu template remains
-- 3. Data inconsistencies during development/testing

-- ============================================================================
-- SECTION 1: IDENTIFY ORPHANED MENUS (READ-ONLY)
-- ============================================================================

-- Query 1: Count total menus and orphaned menus
SELECT
    (SELECT COUNT(*) FROM menus) AS total_menus,
    (SELECT COUNT(*)
     FROM menus m
     LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
     WHERE rm.menu_id IS NULL) AS orphaned_menus,
    (SELECT COUNT(*)
     FROM restaurant_menus) AS total_menu_assignments;

-- Query 2: List all orphaned menus with details
SELECT
    m.id,
    m.name,
    m.description,
    m.vendor_id,
    v.business_name AS vendor_business_name,
    m.is_active,
    m.created_at,
    m.updated_at,
    LENGTH(m.menu_config::TEXT) AS menu_config_size_bytes
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
LEFT JOIN vendors v ON m.vendor_id = v.id
WHERE rm.menu_id IS NULL
ORDER BY m.created_at DESC;

-- Query 3: Group orphaned menus by vendor
SELECT
    COALESCE(v.business_name, 'NO VENDOR (System Menu)') AS vendor,
    m.vendor_id,
    COUNT(m.id) AS orphaned_menu_count
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
LEFT JOIN vendors v ON m.vendor_id = v.id
WHERE rm.menu_id IS NULL
GROUP BY v.business_name, m.vendor_id
ORDER BY orphaned_menu_count DESC;

-- Query 4: Show menus WITH associations for comparison (healthy menus)
SELECT
    m.id AS menu_id,
    m.name AS menu_name,
    COUNT(rm.id) AS restaurant_count,
    STRING_AGG(r.name, ', ' ORDER BY r.name) AS restaurants
FROM menus m
INNER JOIN restaurant_menus rm ON m.id = rm.menu_id
INNER JOIN restaurants r ON rm.restaurant_id = r.id
GROUP BY m.id, m.name
ORDER BY restaurant_count DESC, m.name;

-- ============================================================================
-- SECTION 2: CLEANUP - DELETE ORPHANED MENUS (DESTRUCTIVE OPERATION)
-- ============================================================================

-- INSTRUCTIONS:
-- 1. Review the results from SECTION 1 above
-- 2. Verify you want to delete these menus
-- 3. Uncomment the BEGIN/DELETE/COMMIT block below to execute
-- 4. If unsure, keep it commented and run this script in read-only mode

/*
-- Start transaction (can be rolled back)
BEGIN;

-- Store IDs of menus to be deleted (for logging)
CREATE TEMP TABLE IF NOT EXISTS menus_to_delete AS
SELECT
    m.id,
    m.name,
    m.vendor_id,
    v.business_name AS vendor_name
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
LEFT JOIN vendors v ON m.vendor_id = v.id
WHERE rm.menu_id IS NULL;

-- Display what will be deleted
SELECT
    COUNT(*) AS menus_to_delete,
    STRING_AGG(DISTINCT COALESCE(vendor_name, 'NO VENDOR'), ', ') AS affected_vendors
FROM menus_to_delete;

-- Show details of menus being deleted
SELECT
    id,
    name,
    COALESCE(vendor_name, 'NO VENDOR') AS vendor
FROM menus_to_delete
ORDER BY vendor_name, name;

-- Execute the deletion
DELETE FROM menus
WHERE id IN (SELECT id FROM menus_to_delete);

-- Display deletion summary
SELECT
    (SELECT COUNT(*) FROM menus_to_delete) AS deleted_menu_count,
    (SELECT COUNT(*) FROM menus) AS remaining_menus,
    (SELECT COUNT(*) FROM restaurant_menus) AS remaining_menu_assignments;

-- IMPORTANT: Review the results above
-- If everything looks correct, execute: COMMIT;
-- If you want to undo, execute: ROLLBACK;

-- Uncomment ONE of the lines below:
-- COMMIT;    -- Permanently apply changes
-- ROLLBACK;  -- Undo all changes

-- Clean up temp table
DROP TABLE IF EXISTS menus_to_delete;
*/

-- ============================================================================
-- SECTION 3: VERIFICATION (RUN AFTER DELETE)
-- ============================================================================

-- Verify no orphaned menus remain
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ SUCCESS: No orphaned menus found'
        ELSE '✗ WARNING: ' || COUNT(*) || ' orphaned menus still exist'
    END AS cleanup_status
FROM menus m
LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
WHERE rm.menu_id IS NULL;

-- Show final statistics
SELECT
    (SELECT COUNT(*) FROM menus) AS total_menus,
    (SELECT COUNT(*) FROM restaurant_menus) AS total_menu_assignments,
    (SELECT COUNT(DISTINCT menu_id) FROM restaurant_menus) AS menus_with_associations,
    (SELECT COUNT(*) FROM menus m WHERE NOT EXISTS (
        SELECT 1 FROM restaurant_menus rm WHERE rm.menu_id = m.id
    )) AS orphaned_menus;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- - This script uses a LEFT JOIN to find menus without restaurant_menus entries
-- - The DELETE is wrapped in a transaction for safety (must explicitly COMMIT)
-- - Orphaned menus may be intentional (templates not yet assigned)
-- - Consider adding business logic to prevent menu deletion if recently created
-- - ON DELETE CASCADE on restaurant_menus means deleting restaurants/menus auto-cleans junction table
--
-- ALTERNATIVE SOFT DELETE:
-- Instead of deleting, you could mark as inactive:
--   UPDATE menus SET is_active = FALSE
--   WHERE id IN (SELECT id FROM menus_to_delete);
