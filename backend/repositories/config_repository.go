package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// ConfigRepository defines the interface for system settings operations
type ConfigRepository interface {
	GetAllSettings() ([]models.SystemSetting, error)
	GetSettingByKey(key string) (*models.SystemSetting, error)
	GetSettingsByCategory(category string) ([]models.SystemSetting, error)
	UpdateSetting(key, value string) error
	UpdateMultipleSettings(updates map[string]string) error
	SettingExists(key string) (bool, error)
	GetCategories() ([]string, error)
}

// configRepository is the concrete implementation of ConfigRepository
type configRepository struct {
	db *sqlx.DB
}

// NewConfigRepository creates a new ConfigRepository instance
func NewConfigRepository(db *sqlx.DB) ConfigRepository {
	return &configRepository{db: db}
}

// GetAllSettings retrieves all system settings ordered by category and key
func (r *configRepository) GetAllSettings() ([]models.SystemSetting, error) {
	query := `
		SELECT
			id, setting_key, setting_value, data_type,
			description, category, is_editable,
			created_at, updated_at
		FROM system_settings
		ORDER BY category ASC, setting_key ASC
	`

	settings := make([]models.SystemSetting, 0)
	if err := r.db.Select(&settings, query); err != nil && err != sql.ErrNoRows {
		return settings, fmt.Errorf("failed to retrieve settings: %w", err)
	}

	return settings, nil
}

// GetSettingByKey retrieves a single setting by its unique key
func (r *configRepository) GetSettingByKey(key string) (*models.SystemSetting, error) {
	query := `
		SELECT
			id, setting_key, setting_value, data_type,
			description, category, is_editable,
			created_at, updated_at
		FROM system_settings
		WHERE setting_key = $1
	`

	var setting models.SystemSetting
	if err := r.db.Get(&setting, query, key); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("setting with key '%s' not found", key)
		}
		return nil, fmt.Errorf("failed to retrieve setting: %w", err)
	}

	return &setting, nil
}

// GetSettingsByCategory retrieves all settings in a specific category
func (r *configRepository) GetSettingsByCategory(category string) ([]models.SystemSetting, error) {
	query := `
		SELECT
			id, setting_key, setting_value, data_type,
			description, category, is_editable,
			created_at, updated_at
		FROM system_settings
		WHERE category = $1
		ORDER BY setting_key ASC
	`

	settings := make([]models.SystemSetting, 0)
	if err := r.db.Select(&settings, query, category); err != nil && err != sql.ErrNoRows {
		return settings, fmt.Errorf("failed to retrieve settings for category '%s': %w", category, err)
	}

	return settings, nil
}

// UpdateSetting updates a single setting's value
func (r *configRepository) UpdateSetting(key, value string) error {
	// First, check if the setting exists and is editable
	existingQuery := `
		SELECT id, data_type, is_editable
		FROM system_settings
		WHERE setting_key = $1
	`

	var existing struct {
		ID         int                     `db:"id"`
		DataType   models.SettingDataType  `db:"data_type"`
		IsEditable bool                    `db:"is_editable"`
	}

	if err := r.db.Get(&existing, existingQuery, key); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("setting with key '%s' not found", key)
		}
		return fmt.Errorf("failed to check setting: %w", err)
	}

	// Check if setting is editable
	if !existing.IsEditable {
		return fmt.Errorf("setting '%s' is read-only and cannot be modified", key)
	}

	// Validate the new value
	if err := models.ValidateSettingValue(key, value, existing.DataType); err != nil {
		return fmt.Errorf("validation failed for setting '%s': %w", key, err)
	}

	// Update the setting
	updateQuery := `
		UPDATE system_settings
		SET setting_value = $1, updated_at = CURRENT_TIMESTAMP
		WHERE setting_key = $2 AND is_editable = true
	`

	result, err := r.db.Exec(updateQuery, value, key)
	if err != nil {
		return fmt.Errorf("failed to update setting: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check update result: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("setting '%s' could not be updated (not found or read-only)", key)
	}

	return nil
}

// UpdateMultipleSettings updates multiple settings in a single transaction
func (r *configRepository) UpdateMultipleSettings(updates map[string]string) error {
	// Start a transaction
	tx, err := r.db.Beginx()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}

	// Ensure transaction is rolled back on error
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Prepare statements
	checkQuery := `
		SELECT id, data_type, is_editable
		FROM system_settings
		WHERE setting_key = $1
	`

	updateQuery := `
		UPDATE system_settings
		SET setting_value = $1, updated_at = CURRENT_TIMESTAMP
		WHERE setting_key = $2 AND is_editable = true
	`

	// Process each update
	for key, value := range updates {
		// Check if setting exists and is editable
		var existing struct {
			ID         int                     `db:"id"`
			DataType   models.SettingDataType  `db:"data_type"`
			IsEditable bool                    `db:"is_editable"`
		}

		if err := tx.Get(&existing, checkQuery, key); err != nil {
			if err == sql.ErrNoRows {
				return fmt.Errorf("setting with key '%s' not found", key)
			}
			return fmt.Errorf("failed to check setting '%s': %w", key, err)
		}

		// Check if setting is editable
		if !existing.IsEditable {
			return fmt.Errorf("setting '%s' is read-only and cannot be modified", key)
		}

		// Validate the new value
		if err := models.ValidateSettingValue(key, value, existing.DataType); err != nil {
			return fmt.Errorf("validation failed for setting '%s': %w", key, err)
		}

		// Update the setting
		result, err := tx.Exec(updateQuery, value, key)
		if err != nil {
			return fmt.Errorf("failed to update setting '%s': %w", key, err)
		}

		rowsAffected, err := result.RowsAffected()
		if err != nil {
			return fmt.Errorf("failed to check update result for '%s': %w", key, err)
		}

		if rowsAffected == 0 {
			return fmt.Errorf("setting '%s' could not be updated", key)
		}
	}

	// Commit the transaction
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// SettingExists checks if a setting with the given key exists
func (r *configRepository) SettingExists(key string) (bool, error) {
	query := `SELECT COUNT(*) FROM system_settings WHERE setting_key = $1`

	var count int
	if err := r.db.Get(&count, query, key); err != nil {
		return false, fmt.Errorf("failed to check if setting exists: %w", err)
	}

	return count > 0, nil
}

// GetCategories retrieves all unique categories
func (r *configRepository) GetCategories() ([]string, error) {
	query := `
		SELECT DISTINCT category
		FROM system_settings
		WHERE category IS NOT NULL
		ORDER BY category ASC
	`

	categories := make([]string, 0)
	if err := r.db.Select(&categories, query); err != nil && err != sql.ErrNoRows {
		return categories, fmt.Errorf("failed to retrieve categories: %w", err)
	}

	return categories, nil
}
