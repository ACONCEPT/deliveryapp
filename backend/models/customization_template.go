package models

import "time"

// MenuCustomizationTemplate represents a reusable customization template
type MenuCustomizationTemplate struct {
	ID                   int       `json:"id" db:"id"`
	Name                 string    `json:"name" db:"name"`
	Description          *string   `json:"description,omitempty" db:"description"`
	CustomizationConfig  string    `json:"customization_config" db:"customization_config"` // JSONB as string
	VendorID             *int      `json:"vendor_id,omitempty" db:"vendor_id"`              // Null for system-wide templates
	IsActive             bool      `json:"is_active" db:"is_active"`
	CreatedAt            time.Time `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time `json:"updated_at" db:"updated_at"`
}

// CreateCustomizationTemplateRequest for creating a new customization template
type CreateCustomizationTemplateRequest struct {
	Name                string `json:"name" validate:"required,min=1,max=255"`
	Description         string `json:"description,omitempty"`
	CustomizationConfig string `json:"customization_config" validate:"required"`
	IsActive            bool   `json:"is_active"`
}

// UpdateCustomizationTemplateRequest for updating a customization template (all fields optional)
type UpdateCustomizationTemplateRequest struct {
	Name                *string `json:"name,omitempty"`
	Description         *string `json:"description,omitempty"`
	CustomizationConfig *string `json:"customization_config,omitempty"`
	IsActive            *bool   `json:"is_active,omitempty"`
}

// CustomizationTemplateResponse for API responses
type CustomizationTemplateResponse struct {
	Success bool                       `json:"success"`
	Message string                     `json:"message,omitempty"`
	Data    *MenuCustomizationTemplate `json:"data,omitempty"`
}

// CustomizationTemplatesResponse for list API responses
type CustomizationTemplatesResponse struct {
	Success bool                         `json:"success"`
	Message string                       `json:"message,omitempty"`
	Data    []MenuCustomizationTemplate  `json:"data"`
}
