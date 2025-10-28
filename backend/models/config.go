package models

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// SettingDataType represents the data type of a setting value
type SettingDataType string

const (
	SettingDataTypeString  SettingDataType = "string"
	SettingDataTypeNumber  SettingDataType = "number"
	SettingDataTypeBoolean SettingDataType = "boolean"
	SettingDataTypeJSON    SettingDataType = "json"
)

// SystemSetting represents a system configuration setting
type SystemSetting struct {
	ID           int             `json:"id" db:"id"`
	SettingKey   string          `json:"setting_key" db:"setting_key"`
	SettingValue string          `json:"setting_value" db:"setting_value"`
	DataType     SettingDataType `json:"data_type" db:"data_type"`
	Description  string          `json:"description" db:"description"`
	Category     string          `json:"category" db:"category"`
	IsEditable   bool            `json:"is_editable" db:"is_editable"`
	CreatedAt    time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at" db:"updated_at"`
}

// ============================================================================
// HELPER METHODS
// ============================================================================

// GetAsFloat64 parses the setting value as a float64
func (s *SystemSetting) GetAsFloat64() (float64, error) {
	if s.DataType != SettingDataTypeNumber {
		return 0, fmt.Errorf("setting '%s' is not a number type (is %s)", s.SettingKey, s.DataType)
	}

	value, err := strconv.ParseFloat(s.SettingValue, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse '%s' as float64: %w", s.SettingKey, err)
	}

	return value, nil
}

// GetAsInt parses the setting value as an integer
func (s *SystemSetting) GetAsInt() (int, error) {
	if s.DataType != SettingDataTypeNumber {
		return 0, fmt.Errorf("setting '%s' is not a number type (is %s)", s.SettingKey, s.DataType)
	}

	value, err := strconv.Atoi(s.SettingValue)
	if err != nil {
		return 0, fmt.Errorf("failed to parse '%s' as int: %w", s.SettingKey, err)
	}

	return value, nil
}

// GetAsBool parses the setting value as a boolean
func (s *SystemSetting) GetAsBool() (bool, error) {
	if s.DataType != SettingDataTypeBoolean {
		return false, fmt.Errorf("setting '%s' is not a boolean type (is %s)", s.SettingKey, s.DataType)
	}

	// Parse common boolean representations
	lower := strings.ToLower(strings.TrimSpace(s.SettingValue))
	switch lower {
	case "true", "1", "yes", "on":
		return true, nil
	case "false", "0", "no", "off":
		return false, nil
	default:
		return false, fmt.Errorf("invalid boolean value for '%s': %s", s.SettingKey, s.SettingValue)
	}
}

// GetAsJSON parses the setting value as JSON into the provided interface
func (s *SystemSetting) GetAsJSON(dest interface{}) error {
	if s.DataType != SettingDataTypeJSON {
		return fmt.Errorf("setting '%s' is not a json type (is %s)", s.SettingKey, s.DataType)
	}

	if err := json.Unmarshal([]byte(s.SettingValue), dest); err != nil {
		return fmt.Errorf("failed to parse '%s' as JSON: %w", s.SettingKey, err)
	}

	return nil
}

// Validate checks if the setting value is valid for its data type
func (s *SystemSetting) Validate() error {
	switch s.DataType {
	case SettingDataTypeNumber:
		if _, err := strconv.ParseFloat(s.SettingValue, 64); err != nil {
			return fmt.Errorf("invalid number value: %s", s.SettingValue)
		}
	case SettingDataTypeBoolean:
		lower := strings.ToLower(strings.TrimSpace(s.SettingValue))
		validBooleans := []string{"true", "false", "1", "0", "yes", "no", "on", "off"}
		valid := false
		for _, v := range validBooleans {
			if lower == v {
				valid = true
				break
			}
		}
		if !valid {
			return fmt.Errorf("invalid boolean value: %s", s.SettingValue)
		}
	case SettingDataTypeJSON:
		var js interface{}
		if err := json.Unmarshal([]byte(s.SettingValue), &js); err != nil {
			return fmt.Errorf("invalid JSON value: %w", err)
		}
	case SettingDataTypeString:
		// String is always valid
	default:
		return fmt.Errorf("unknown data type: %s", s.DataType)
	}

	return nil
}

// ============================================================================
// REQUEST/RESPONSE DTOs
// ============================================================================

// UpdateSettingRequest represents a request to update a single setting
type UpdateSettingRequest struct {
	Value string `json:"value" validate:"required"`
}

// BatchUpdateSettingRequest represents a single setting update in a batch
type BatchUpdateSettingRequest struct {
	Key   string `json:"key" validate:"required"`
	Value string `json:"value" validate:"required"`
}

// UpdateMultipleSettingsRequest represents a request to update multiple settings
type UpdateMultipleSettingsRequest struct {
	Settings []BatchUpdateSettingRequest `json:"settings" validate:"required,min=1"`
}

// SettingsByCategory represents settings grouped by category
type SettingsByCategory map[string][]SystemSetting

// SettingsResponse represents the response with settings grouped by category
type SettingsResponse struct {
	Settings           SettingsByCategory `json:"settings"`
	TotalCount         int                `json:"total_count"`
	CategoriesCount    int                `json:"categories_count"`
}

// SettingValidationError represents a validation error for a specific setting
type SettingValidationError struct {
	Key     string `json:"key"`
	Message string `json:"message"`
}

// BatchUpdateResult represents the result of a batch update operation
type BatchUpdateResult struct {
	SuccessCount int                      `json:"success_count"`
	FailureCount int                      `json:"failure_count"`
	Errors       []SettingValidationError `json:"errors,omitempty"`
	UpdatedKeys  []string                 `json:"updated_keys"`
}

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

// ValidateNumberRange validates that a number setting is within a specific range
func ValidateNumberRange(value string, min, max float64) error {
	num, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return fmt.Errorf("invalid number: %w", err)
	}

	if num < min || num > max {
		return fmt.Errorf("value %.2f out of range [%.2f, %.2f]", num, min, max)
	}

	return nil
}

// ValidatePositiveNumber validates that a number setting is positive
func ValidatePositiveNumber(value string) error {
	num, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return fmt.Errorf("invalid number: %w", err)
	}

	if num <= 0 {
		return fmt.Errorf("value must be positive, got %.2f", num)
	}

	return nil
}

// ValidateNonNegativeNumber validates that a number setting is non-negative
func ValidateNonNegativeNumber(value string) error {
	num, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return fmt.Errorf("invalid number: %w", err)
	}

	if num < 0 {
		return fmt.Errorf("value must be non-negative, got %.2f", num)
	}

	return nil
}

// ValidateSettingValue performs additional validation based on setting key
func ValidateSettingValue(key, value string, dataType SettingDataType) error {
	// First, validate the data type
	tempSetting := &SystemSetting{
		SettingKey:   key,
		SettingValue: value,
		DataType:     dataType,
	}

	if err := tempSetting.Validate(); err != nil {
		return err
	}

	// Additional validation based on specific keys
	switch key {
	case "tax_rate", "platform_commission_rate", "driver_commission_rate":
		// Rates should be between 0 and 1
		if err := ValidateNumberRange(value, 0, 1); err != nil {
			return fmt.Errorf("%s must be between 0 and 1: %w", key, err)
		}

	case "minimum_order_amount", "default_delivery_fee":
		// These should be positive
		if err := ValidatePositiveNumber(value); err != nil {
			return fmt.Errorf("%s must be positive: %w", key, err)
		}

	case "max_delivery_radius_km", "order_auto_cancel_minutes",
	     "estimated_prep_time_default", "estimated_delivery_time_per_km":
		// These should be positive
		if err := ValidatePositiveNumber(value); err != nil {
			return fmt.Errorf("%s must be positive: %w", key, err)
		}
	}

	return nil
}
