package repositories

import (
	"fmt"

	"github.com/jmoiron/sqlx"
)

// ApprovalConfig defines the table and column names for approval operations
type ApprovalConfig struct {
	TableName          string
	IDColumn           string
	ApprovalStatusCol  string
	ApprovedByCol      string
	ApprovedAtCol      string
	IsActiveCol        string
	RejectionReasonCol string
}

// ApproveEntity sets entity to approved status
func ApproveEntity(db *sqlx.DB, config ApprovalConfig, entityID, adminID int) error {
	query := db.Rebind(fmt.Sprintf(`
		UPDATE %s
		SET
			%s = 'approved',
			%s = ?,
			%s = CURRENT_TIMESTAMP,
			%s = true,
			%s = NULL,
			updated_at = CURRENT_TIMESTAMP
		WHERE %s = ?
	`, config.TableName, config.ApprovalStatusCol, config.ApprovedByCol,
		config.ApprovedAtCol, config.IsActiveCol, config.RejectionReasonCol,
		config.IDColumn))

	result, err := ExecuteStatement(db, query, []interface{}{adminID, entityID})
	if err != nil {
		return fmt.Errorf("failed to approve %s: %w", config.TableName, err)
	}

	return CheckRowsAffected(result, config.TableName)
}

// RejectEntity sets entity to rejected status
func RejectEntity(db *sqlx.DB, config ApprovalConfig, entityID, adminID int, reason string) error {
	query := db.Rebind(fmt.Sprintf(`
		UPDATE %s
		SET
			%s = 'rejected',
			%s = ?,
			%s = CURRENT_TIMESTAMP,
			%s = false,
			%s = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE %s = ?
	`, config.TableName, config.ApprovalStatusCol, config.ApprovedByCol,
		config.ApprovedAtCol, config.IsActiveCol, config.RejectionReasonCol,
		config.IDColumn))

	result, err := ExecuteStatement(db, query, []interface{}{adminID, reason, entityID})
	if err != nil {
		return fmt.Errorf("failed to reject %s: %w", config.TableName, err)
	}

	return CheckRowsAffected(result, config.TableName)
}
