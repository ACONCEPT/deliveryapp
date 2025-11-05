package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// CustomizationTemplateRepository interface defines customization template data access methods
type CustomizationTemplateRepository interface {
	Create(template *models.MenuCustomizationTemplate) error
	GetByID(id int) (*models.MenuCustomizationTemplate, error)
	GetByVendorID(vendorID int) ([]models.MenuCustomizationTemplate, error)
	GetAll() ([]models.MenuCustomizationTemplate, error)
	GetSystemWide() ([]models.MenuCustomizationTemplate, error)
	Update(template *models.MenuCustomizationTemplate) error
	Delete(id int) error
	VerifyVendorOwnership(templateID, vendorID int) error
}

type customizationTemplateRepository struct {
	DB *sqlx.DB
}

// NewCustomizationTemplateRepository creates a new customization template repository
func NewCustomizationTemplateRepository(db *sqlx.DB) CustomizationTemplateRepository {
	return &customizationTemplateRepository{DB: db}
}

// Create inserts a new customization template
func (r *customizationTemplateRepository) Create(template *models.MenuCustomizationTemplate) error {
	query := r.DB.Rebind(`
		INSERT INTO menu_customization_templates (name, description, customization_config, vendor_id, is_active)
		VALUES (?, ?, ?, ?, ?)
		RETURNING id, name, description, customization_config, vendor_id, is_active, created_at, updated_at
	`)

	args := []interface{}{
		template.Name,
		template.Description,
		template.CustomizationConfig,
		template.VendorID,
		template.IsActive,
	}

	return GetData(r.DB, query, template, args)
}

// GetByID retrieves a customization template by ID
func (r *customizationTemplateRepository) GetByID(id int) (*models.MenuCustomizationTemplate, error) {
	var template models.MenuCustomizationTemplate
	query := r.DB.Rebind(`SELECT * FROM menu_customization_templates WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&template)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("customization template not found")
		}
		return nil, fmt.Errorf("failed to get customization template: %w", err)
	}

	return &template, nil
}

// GetByVendorID retrieves all customization templates owned by a vendor (includes system-wide templates)
func (r *customizationTemplateRepository) GetByVendorID(vendorID int) ([]models.MenuCustomizationTemplate, error) {
	templates := make([]models.MenuCustomizationTemplate, 0)

	// Get vendor's own templates plus system-wide templates (vendor_id IS NULL)
	query := r.DB.Rebind(`
		SELECT * FROM menu_customization_templates
		WHERE vendor_id = ? OR vendor_id IS NULL
		ORDER BY vendor_id NULLS FIRST, name ASC
	`)

	err := SelectData(r.DB, query, &templates, []interface{}{vendorID})
	if err != nil {
		return templates, fmt.Errorf("failed to get customization templates: %w", err)
	}

	return templates, nil
}

// GetAll retrieves all customization templates (admin only)
func (r *customizationTemplateRepository) GetAll() ([]models.MenuCustomizationTemplate, error) {
	templates := make([]models.MenuCustomizationTemplate, 0)
	query := `SELECT * FROM menu_customization_templates ORDER BY vendor_id NULLS FIRST, name ASC`

	err := SelectData(r.DB, query, &templates, []interface{}{})
	if err != nil {
		return templates, fmt.Errorf("failed to get all customization templates: %w", err)
	}

	return templates, nil
}

// GetSystemWide retrieves all system-wide customization templates (vendor_id IS NULL)
func (r *customizationTemplateRepository) GetSystemWide() ([]models.MenuCustomizationTemplate, error) {
	templates := make([]models.MenuCustomizationTemplate, 0)
	query := `SELECT * FROM menu_customization_templates WHERE vendor_id IS NULL ORDER BY name ASC`

	err := SelectData(r.DB, query, &templates, []interface{}{})
	if err != nil {
		return templates, fmt.Errorf("failed to get system-wide customization templates: %w", err)
	}

	return templates, nil
}

// Update updates a customization template
func (r *customizationTemplateRepository) Update(template *models.MenuCustomizationTemplate) error {
	query := r.DB.Rebind(`
		UPDATE menu_customization_templates
		SET name = ?, description = ?, customization_config = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
		RETURNING id, name, description, customization_config, vendor_id, is_active, created_at, updated_at
	`)

	args := []interface{}{
		template.Name,
		template.Description,
		template.CustomizationConfig,
		template.IsActive,
		template.ID,
	}

	return GetData(r.DB, query, template, args)
}

// Delete deletes a customization template
func (r *customizationTemplateRepository) Delete(id int) error {
	query := r.DB.Rebind(`DELETE FROM menu_customization_templates WHERE id = ?`)

	result, err := r.DB.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete customization template: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("customization template not found")
	}

	return nil
}

// VerifyVendorOwnership verifies that a vendor owns a customization template
func (r *customizationTemplateRepository) VerifyVendorOwnership(templateID, vendorID int) error {
	var count int
	query := r.DB.Rebind(`
		SELECT COUNT(*) FROM menu_customization_templates
		WHERE id = ? AND vendor_id = ?
	`)

	err := r.DB.QueryRow(query, templateID, vendorID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to verify ownership: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("customization template not found or access denied")
	}

	return nil
}
