package repositories

import (
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// ApprovalRepository defines the interface for approval-related data access
type ApprovalRepository interface {
	// Approval history tracking
	CreateApprovalHistory(history *models.ApprovalHistory) error
	GetEntityApprovalHistory(entityType string, entityID int) ([]models.ApprovalHistory, error)
	GetAdminApprovalHistory(adminID int) ([]models.ApprovalHistory, error)

	// Dashboard statistics
	GetApprovalStats() (*models.ApprovalDashboardResponse, error)
}

// approvalRepository implements the ApprovalRepository interface
type approvalRepository struct {
	DB *sqlx.DB
}

// NewApprovalRepository creates a new instance of ApprovalRepository
func NewApprovalRepository(db *sqlx.DB) ApprovalRepository {
	return &approvalRepository{DB: db}
}

// CreateApprovalHistory records an approval/rejection event
func (r *approvalRepository) CreateApprovalHistory(history *models.ApprovalHistory) error {
	query := r.DB.Rebind(`
		INSERT INTO approval_history (entity_type, entity_id, admin_id, action, reason)
		VALUES (?, ?, ?, ?, ?)
		RETURNING id, entity_type, entity_id, admin_id, action, reason, created_at
	`)

	args := []interface{}{
		history.EntityType,
		history.EntityID,
		history.AdminID,
		history.Action,
		history.Reason,
	}

	return GetData(r.DB, query, history, args)
}

// GetEntityApprovalHistory retrieves approval history for a specific entity
func (r *approvalRepository) GetEntityApprovalHistory(entityType string, entityID int) ([]models.ApprovalHistory, error) {
	history := make([]models.ApprovalHistory, 0)
	query := r.DB.Rebind(`
		SELECT
			ah.id, ah.entity_type, ah.entity_id, ah.admin_id, ah.action, ah.reason, ah.created_at
		FROM approval_history ah
		WHERE ah.entity_type = ? AND ah.entity_id = ?
		ORDER BY ah.created_at DESC
	`)

	err := SelectData(r.DB, query, &history, []interface{}{entityType, entityID})
	if err != nil {
		return history, fmt.Errorf("failed to get approval history: %w", err)
	}

	return history, nil
}

// GetAdminApprovalHistory retrieves all approvals/rejections performed by a specific admin
func (r *approvalRepository) GetAdminApprovalHistory(adminID int) ([]models.ApprovalHistory, error) {
	history := make([]models.ApprovalHistory, 0)
	query := r.DB.Rebind(`
		SELECT
			ah.id, ah.entity_type, ah.entity_id, ah.admin_id, ah.action, ah.reason, ah.created_at
		FROM approval_history ah
		WHERE ah.admin_id = ?
		ORDER BY ah.created_at DESC
	`)

	err := SelectData(r.DB, query, &history, []interface{}{adminID})
	if err != nil {
		return history, fmt.Errorf("failed to get admin approval history: %w", err)
	}

	return history, nil
}

// GetApprovalStats retrieves summary statistics for the approval dashboard
func (r *approvalRepository) GetApprovalStats() (*models.ApprovalDashboardResponse, error) {
	stats := &models.ApprovalDashboardResponse{}

	// Count pending vendors
	err := r.DB.QueryRow(`
		SELECT COUNT(*) FROM vendors WHERE approval_status = 'pending'
	`).Scan(&stats.PendingVendors)
	if err != nil {
		return nil, fmt.Errorf("failed to count pending vendors: %w", err)
	}

	// Count approved vendors
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM vendors WHERE approval_status = 'approved'
	`).Scan(&stats.ApprovedVendors)
	if err != nil {
		return nil, fmt.Errorf("failed to count approved vendors: %w", err)
	}

	// Count rejected vendors
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM vendors WHERE approval_status = 'rejected'
	`).Scan(&stats.RejectedVendors)
	if err != nil {
		return nil, fmt.Errorf("failed to count rejected vendors: %w", err)
	}

	// Count pending restaurants
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM restaurants WHERE approval_status = 'pending'
	`).Scan(&stats.PendingRestaurants)
	if err != nil {
		return nil, fmt.Errorf("failed to count pending restaurants: %w", err)
	}

	// Count approved restaurants
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM restaurants WHERE approval_status = 'approved'
	`).Scan(&stats.ApprovedRestaurants)
	if err != nil {
		return nil, fmt.Errorf("failed to count approved restaurants: %w", err)
	}

	// Count rejected restaurants
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM restaurants WHERE approval_status = 'rejected'
	`).Scan(&stats.RejectedRestaurants)
	if err != nil {
		return nil, fmt.Errorf("failed to count rejected restaurants: %w", err)
	}

	// Count pending drivers
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM drivers WHERE approval_status = 'pending'
	`).Scan(&stats.PendingDrivers)
	if err != nil {
		return nil, fmt.Errorf("failed to count pending drivers: %w", err)
	}

	// Count approved drivers
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM drivers WHERE approval_status = 'approved'
	`).Scan(&stats.ApprovedDrivers)
	if err != nil {
		return nil, fmt.Errorf("failed to count approved drivers: %w", err)
	}

	// Count rejected drivers
	err = r.DB.QueryRow(`
		SELECT COUNT(*) FROM drivers WHERE approval_status = 'rejected'
	`).Scan(&stats.RejectedDrivers)
	if err != nil {
		return nil, fmt.Errorf("failed to count rejected drivers: %w", err)
	}

	return stats, nil
}
