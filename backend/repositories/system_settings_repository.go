package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/jmoiron/sqlx"
)

// SystemSettingsRepository defines the interface for system settings data access
type SystemSettingsRepository interface {
	GetAll() ([]models.SystemSetting, error)
	GetByCategory(category string) ([]models.SystemSetting, error)
	GetByKey(key string) (*models.SystemSetting, error)
	GetAllCategories() ([]string, error)
	Update(key, value string) (*models.SystemSetting, error)
	BatchUpdate(updates map[string]string) (successCount int, failureCount int, errors []models.SettingValidationError, updatedKeys []string, err error)
	ValidateValue(value string, dataType string) error
}

// systemSettingsRepository implements the SystemSettingsRepository interface
type systemSettingsRepository struct {
	DB *sqlx.DB
}

// NewSystemSettingsRepository creates a new instance of SystemSettingsRepository
func NewSystemSettingsRepository(db *sqlx.DB) SystemSettingsRepository {
	return &systemSettingsRepository{DB: db}
}

// GetAll retrieves all system settings
func (r *systemSettingsRepository) GetAll() ([]models.SystemSetting, error) {
	settings := make([]models.SystemSetting, 0)
	query := `
		SELECT id, setting_key, setting_value, data_type, description, category, is_editable, created_at, updated_at
		FROM system_settings
		ORDER BY category, setting_key
	`

	err := SelectData(r.DB, query, &settings, []interface{}{})
	if err != nil {
		return settings, fmt.Errorf("failed to fetch settings: %w", err)
	}

	return settings, nil
}

// GetByCategory retrieves settings filtered by category
func (r *systemSettingsRepository) GetByCategory(category string) ([]models.SystemSetting, error) {
	settings := make([]models.SystemSetting, 0)
	query := `
		SELECT id, setting_key, setting_value, data_type, description, category, is_editable, created_at, updated_at
		FROM system_settings
		WHERE category = $1
		ORDER BY setting_key
	`

	err := SelectData(r.DB, query, &settings, []interface{}{category})
	if err != nil {
		return settings, fmt.Errorf("failed to fetch settings for category %s: %w", category, err)
	}

	return settings, nil
}

// GetByKey retrieves a single setting by its key
func (r *systemSettingsRepository) GetByKey(key string) (*models.SystemSetting, error) {
	var setting models.SystemSetting
	query := `
		SELECT id, setting_key, setting_value, data_type, description, category, is_editable, created_at, updated_at
		FROM system_settings
		WHERE setting_key = $1
	`

	err := GetData(r.DB, query, &setting, []interface{}{key})
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("setting not found: %s", key)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to fetch setting %s: %w", key, err)
	}

	return &setting, nil
}

// GetAllCategories retrieves list of unique categories
func (r *systemSettingsRepository) GetAllCategories() ([]string, error) {
	categories := make([]string, 0)
	query := `
		SELECT DISTINCT category
		FROM system_settings
		ORDER BY category
	`

	rows, err := Query(r.DB, query, []interface{}{})
	if err != nil {
		return categories, fmt.Errorf("failed to fetch categories: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var category string
		if err := rows.Scan(&category); err != nil {
			return nil, fmt.Errorf("failed to scan category: %w", err)
		}
		categories = append(categories, category)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating categories: %w", err)
	}

	return categories, nil
}

// Update updates a single setting value
func (r *systemSettingsRepository) Update(key, value string) (*models.SystemSetting, error) {
	// First, get the setting to check if it's editable and get data type
	setting, err := r.GetByKey(key)
	if err != nil {
		return nil, err
	}

	if !setting.IsEditable {
		return nil, fmt.Errorf("setting %s is read-only", key)
	}

	// Validate the value based on data type
	if err := r.ValidateValue(value, string(setting.DataType)); err != nil {
		return nil, fmt.Errorf("validation error for %s: %w", key, err)
	}

	// Update the setting
	query := `
		UPDATE system_settings
		SET setting_value = $1, updated_at = CURRENT_TIMESTAMP
		WHERE setting_key = $2
		RETURNING id, setting_key, setting_value, data_type, description, category, is_editable, created_at, updated_at
	`

	var updatedSetting models.SystemSetting
	err = GetData(r.DB, query, &updatedSetting, []interface{}{value, key})
	if err != nil {
		return nil, fmt.Errorf("failed to update setting %s: %w", key, err)
	}

	return &updatedSetting, nil
}

// BatchUpdate updates multiple settings in a transaction
func (r *systemSettingsRepository) BatchUpdate(updates map[string]string) (successCount int, failureCount int, errors []models.SettingValidationError, updatedKeys []string, err error) {
	// Start a transaction
	tx, err := r.DB.Beginx()
	if err != nil {
		return 0, 0, nil, nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p)
		}
	}()

	errors = []models.SettingValidationError{}
	updatedKeys = []string{}

	for key, value := range updates {
		// Get the setting to check editability and data type
		var setting models.SystemSetting
		query := `SELECT id, setting_key, setting_value, data_type, description, category, is_editable, created_at, updated_at FROM system_settings WHERE setting_key = $1`
		err := tx.Get(&setting, query, key)
		if err == sql.ErrNoRows {
			errors = append(errors, models.SettingValidationError{
				Key:     key,
				Message: "Setting not found",
			})
			failureCount++
			continue
		}
		if err != nil {
			errors = append(errors, models.SettingValidationError{
				Key:     key,
				Message: fmt.Sprintf("Database error: %v", err),
			})
			failureCount++
			continue
		}

		// Check if editable
		if !setting.IsEditable {
			errors = append(errors, models.SettingValidationError{
				Key:     key,
				Message: "Setting is read-only",
			})
			failureCount++
			continue
		}

		// Validate value
		if validationErr := r.ValidateValue(value, string(setting.DataType)); validationErr != nil {
			errors = append(errors, models.SettingValidationError{
				Key:     key,
				Message: fmt.Sprintf("Validation error: %v", validationErr),
			})
			failureCount++
			continue
		}

		// Update the setting
		updateQuery := `UPDATE system_settings SET setting_value = $1, updated_at = CURRENT_TIMESTAMP WHERE setting_key = $2`
		_, err = tx.Exec(updateQuery, value, key)
		if err != nil {
			errors = append(errors, models.SettingValidationError{
				Key:     key,
				Message: fmt.Sprintf("Update failed: %v", err),
			})
			failureCount++
			continue
		}

		successCount++
		updatedKeys = append(updatedKeys, key)
	}

	// Commit the transaction if at least one update succeeded
	if successCount > 0 {
		if err := tx.Commit(); err != nil {
			return 0, 0, nil, nil, fmt.Errorf("failed to commit transaction: %w", err)
		}
	} else {
		tx.Rollback()
	}

	return successCount, failureCount, errors, updatedKeys, nil
}

// ValidateValue validates a setting value based on its data type
func (r *systemSettingsRepository) ValidateValue(value string, dataType string) error {
	switch dataType {
	case "number":
		_, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return fmt.Errorf("value must be a valid number")
		}
	case "boolean":
		if value != "true" && value != "false" {
			return fmt.Errorf("value must be 'true' or 'false'")
		}
	case "json":
		var js interface{}
		if err := json.Unmarshal([]byte(value), &js); err != nil {
			return fmt.Errorf("value must be valid JSON: %w", err)
		}
	case "string":
		if len(value) == 0 {
			return fmt.Errorf("value cannot be empty")
		}
	default:
		return fmt.Errorf("unknown data type: %s", dataType)
	}
	return nil
}
