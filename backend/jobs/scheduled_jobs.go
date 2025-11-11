package jobs

import (
	"fmt"
	"log"
	"time"

	"github.com/jmoiron/sqlx"
)

// CancelUnconfirmedOrders cancels orders that vendors haven't confirmed within 30 minutes
// Runs: Every minute
// Purpose: Ensure timely vendor response, improve customer experience
func CancelUnconfirmedOrders(db *sqlx.DB) error {
	log.Println("[JOB] Running CancelUnconfirmedOrders...")

	query := `
		UPDATE orders
		SET
			status = 'cancelled'::order_status,
			cancelled_at = CURRENT_TIMESTAMP,
			cancellation_reason = 'Order not confirmed by vendor within 30 minutes',
			updated_at = CURRENT_TIMESTAMP
		WHERE
			status = 'pending'
			AND placed_at IS NOT NULL
			AND placed_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
			AND cancelled_at IS NULL
		RETURNING id
	`

	rows, err := db.Query(query)
	if err != nil {
		return fmt.Errorf("failed to cancel unconfirmed orders: %w", err)
	}
	defer rows.Close()

	count := 0
	var orderIDs []int
	for rows.Next() {
		var orderID int
		if err := rows.Scan(&orderID); err != nil {
			log.Printf("[ERROR] Failed to scan order ID: %v", err)
			continue
		}
		orderIDs = append(orderIDs, orderID)
		count++
	}

	if count > 0 {
		log.Printf("[JOB] CancelUnconfirmedOrders: Cancelled %d orders: %v", count, orderIDs)
	} else {
		log.Println("[JOB] CancelUnconfirmedOrders: No orders to cancel")
	}

	return nil
}

// CleanupOrphanedMenus removes menus not linked to any restaurants older than 30 days
// Runs: Daily at 2 AM
// Purpose: Clean up unused menu templates to reduce database bloat
func CleanupOrphanedMenus(db *sqlx.DB) error {
	log.Println("[JOB] Running CleanupOrphanedMenus...")

	query := `
		DELETE FROM menus
		WHERE id IN (
			SELECT m.id
			FROM menus m
			LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
			WHERE rm.id IS NULL
			  AND m.created_at < CURRENT_TIMESTAMP - INTERVAL '30 days'
			  AND m.is_active = false
		)
		RETURNING id, name
	`

	rows, err := db.Query(query)
	if err != nil {
		return fmt.Errorf("failed to cleanup orphaned menus: %w", err)
	}
	defer rows.Close()

	count := 0
	var menuNames []string
	for rows.Next() {
		var menuID int
		var menuName string
		if err := rows.Scan(&menuID, &menuName); err != nil {
			log.Printf("[ERROR] Failed to scan menu details: %v", err)
			continue
		}
		menuNames = append(menuNames, fmt.Sprintf("%d:%s", menuID, menuName))
		count++
	}

	if count > 0 {
		log.Printf("[JOB] CleanupOrphanedMenus: Deleted %d menus: %v", count, menuNames)
	} else {
		log.Println("[JOB] CleanupOrphanedMenus: No orphaned menus to delete")
	}

	return nil
}

// ArchiveOldOrders marks old delivered/cancelled orders as inactive (older than 90 days)
// Runs: Weekly on Sunday at 3 AM
// Purpose: Improve query performance by reducing active order dataset
func ArchiveOldOrders(db *sqlx.DB) error {
	log.Println("[JOB] Running ArchiveOldOrders...")

	query := `
		UPDATE orders
		SET
			is_active = false,
			updated_at = CURRENT_TIMESTAMP
		WHERE
			is_active = true
			AND status IN ('delivered', 'cancelled', 'refunded')
			AND (
				delivered_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
				OR cancelled_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
			)
		RETURNING id
	`

	rows, err := db.Query(query)
	if err != nil {
		return fmt.Errorf("failed to archive old orders: %w", err)
	}
	defer rows.Close()

	count := 0
	var orderIDs []int
	for rows.Next() {
		var orderID int
		if err := rows.Scan(&orderID); err != nil {
			log.Printf("[ERROR] Failed to scan order ID: %v", err)
			continue
		}
		orderIDs = append(orderIDs, orderID)
		count++
	}

	if count > 0 {
		log.Printf("[JOB] ArchiveOldOrders: Archived %d orders", count)
		log.Printf("[JOB] ArchiveOldOrders: Sample order IDs: %v", orderIDs[:min(10, len(orderIDs))])
	} else {
		log.Println("[JOB] ArchiveOldOrders: No orders to archive")
	}

	return nil
}

// UpdateDriverAvailability marks drivers as unavailable if they haven't updated location in 30 minutes
// Runs: Every 5 minutes
// Purpose: Ensure driver availability status is accurate for order assignment
func UpdateDriverAvailability(db *sqlx.DB) error {
	log.Println("[JOB] Running UpdateDriverAvailability...")

	query := `
		UPDATE drivers
		SET
			is_available = false,
			updated_at = CURRENT_TIMESTAMP
		WHERE
			is_available = true
			AND updated_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
		RETURNING id, full_name
	`

	rows, err := db.Query(query)
	if err != nil {
		return fmt.Errorf("failed to update driver availability: %w", err)
	}
	defer rows.Close()

	count := 0
	var driverNames []string
	for rows.Next() {
		var driverID int
		var fullName string
		if err := rows.Scan(&driverID, &fullName); err != nil {
			log.Printf("[ERROR] Failed to scan driver details: %v", err)
			continue
		}
		driverNames = append(driverNames, fmt.Sprintf("%d:%s", driverID, fullName))
		count++
	}

	if count > 0 {
		log.Printf("[JOB] UpdateDriverAvailability: Marked %d drivers as unavailable: %v", count, driverNames)
	} else {
		log.Println("[JOB] UpdateDriverAvailability: No drivers to update")
	}

	return nil
}

// Helper function to get minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// GetCurrentTimestamp returns the current timestamp for logging/debugging
func GetCurrentTimestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}
