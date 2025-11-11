package repositories

import (
	"fmt"

	"github.com/jmoiron/sqlx"
)

// VerifyOwnershipByForeignKey checks if entity belongs to owner by foreign key
func VerifyOwnershipByForeignKey(db *sqlx.DB, tableName, idCol, ownerCol string, entityID, ownerID int) error {
	var count int
	query := db.Rebind(fmt.Sprintf(`
		SELECT COUNT(*) FROM %s
		WHERE %s = ? AND %s = ?
	`, tableName, idCol, ownerCol))

	err := db.QueryRow(query, entityID, ownerID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to verify ownership: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("%s does not belong to owner or not found", tableName)
	}

	return nil
}

// VerifyOwnershipByJunction checks ownership through junction table
func VerifyOwnershipByJunction(db *sqlx.DB, junctionTable, entityCol, ownerCol string, entityID, ownerID int) error {
	var count int
	query := db.Rebind(fmt.Sprintf(`
		SELECT COUNT(*) FROM %s
		WHERE %s = ? AND %s = ?
	`, junctionTable, entityCol, ownerCol))

	err := db.QueryRow(query, entityID, ownerID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to verify ownership: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("ownership not found or access denied")
	}

	return nil
}
