package repositories

import (
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
	*BaseRepository[models.MenuCustomizationTemplate]
	DB *sqlx.DB
}

// NewCustomizationTemplateRepository creates a new customization template repository
func NewCustomizationTemplateRepository(db *sqlx.DB) CustomizationTemplateRepository {
	return &customizationTemplateRepository{
		BaseRepository: NewBaseRepository[models.MenuCustomizationTemplate](db, "menu_customization_templates"),
		DB:             db,
	}
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
// Inherited from BaseRepository[models.MenuCustomizationTemplate]

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
// Inherited from BaseRepository[models.MenuCustomizationTemplate]

// VerifyVendorOwnership verifies that a vendor owns a customization template
func (r *customizationTemplateRepository) VerifyVendorOwnership(templateID, vendorID int) error {
	return VerifyOwnershipByForeignKey(r.DB, "menu_customization_templates", "id", "vendor_id", templateID, vendorID)
}
