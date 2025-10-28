package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// MenuRepository interface defines menu data access methods
type MenuRepository interface {
	// Menu CRUD
	Create(menu *models.Menu) error
	GetByID(id int) (*models.Menu, error)
	GetAll() ([]models.Menu, error)
	GetByVendorID(vendorID int) ([]models.MenuWithRestaurants, error)
	Update(menu *models.Menu) error
	Delete(id int) error

	// Restaurant-Menu assignments
	AssignToRestaurant(restaurantMenu *models.RestaurantMenu) error
	UnassignFromRestaurant(restaurantID, menuID int) error
	GetRestaurantMenu(restaurantID, menuID int) (*models.RestaurantMenu, error)
	GetActiveMenuByRestaurantID(restaurantID int) (*models.Menu, error)
	GetMenusByRestaurantID(restaurantID int) ([]models.Menu, error)
	SetActiveMenu(restaurantID, menuID int) error

	// Validation helpers
	IsMenuAssignedToRestaurants(menuID int) (bool, int, error)
	DoesRestaurantHaveMenu(restaurantID, menuID int) (bool, error)
	DoesVendorOwnMenu(vendorID, menuID int) (bool, error)
}

type menuRepository struct {
	DB *sqlx.DB
}

// NewMenuRepository creates a new menu repository
func NewMenuRepository(db *sqlx.DB) MenuRepository {
	return &menuRepository{DB: db}
}

// Create inserts a new menu
func (r *menuRepository) Create(menu *models.Menu) error {
	query := r.DB.Rebind(`
		INSERT INTO menus (name, description, menu_config, vendor_id, is_active)
		VALUES (?, ?, ?, ?, ?)
		RETURNING id, name, description, menu_config, vendor_id, is_active, created_at, updated_at
	`)

	args := []interface{}{
		menu.Name,
		menu.Description,
		menu.MenuConfig,
		menu.VendorID,
		menu.IsActive,
	}

	return GetData(r.DB, query, menu, args)
}

// GetByID retrieves a menu by ID
func (r *menuRepository) GetByID(id int) (*models.Menu, error) {
	var menu models.Menu
	query := r.DB.Rebind(`SELECT * FROM menus WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&menu)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("menu not found")
		}
		return nil, fmt.Errorf("failed to get menu: %w", err)
	}

	return &menu, nil
}

// GetAll retrieves all menus
func (r *menuRepository) GetAll() ([]models.Menu, error) {
	menus := make([]models.Menu, 0)
	query := `SELECT * FROM menus ORDER BY created_at DESC`

	err := SelectData(r.DB, query, &menus, []interface{}{})
	if err != nil {
		return menus, fmt.Errorf("failed to get menus: %w", err)
	}

	return menus, nil
}

// GetByVendorID retrieves all menus owned by a vendor
func (r *menuRepository) GetByVendorID(vendorID int) ([]models.MenuWithRestaurants, error) {
	// Get all menus owned by vendor (includes unassigned menus)
	query := r.DB.Rebind(`
		SELECT * FROM menus
		WHERE vendor_id = ?
		ORDER BY created_at DESC
	`)

	menus := make([]models.Menu, 0)
	err := SelectData(r.DB, query, &menus, []interface{}{vendorID})
	if err != nil {
		return make([]models.MenuWithRestaurants, 0), fmt.Errorf("failed to get menus by vendor: %w", err)
	}

	// For each menu, get assigned restaurants (if any)
	result := make([]models.MenuWithRestaurants, len(menus))
	for i, menu := range menus {
		result[i].Menu = menu
		// Initialize with empty slice instead of nil
		result[i].AssignedRestaurants = make([]models.RestaurantMenuAssignment, 0)

		assignmentQuery := r.DB.Rebind(`
			SELECT rm.restaurant_id, r.name as restaurant_name, rm.is_active, rm.display_order
			FROM restaurant_menus rm
			JOIN restaurants r ON rm.restaurant_id = r.id
			JOIN vendor_restaurants vr ON r.id = vr.restaurant_id
			WHERE rm.menu_id = ? AND vr.vendor_id = ?
			ORDER BY rm.display_order
		`)

		assignments := make([]models.RestaurantMenuAssignment, 0)
		err = SelectData(r.DB, assignmentQuery, &assignments, []interface{}{menu.ID, vendorID})
		if err == nil && len(assignments) > 0 {
			result[i].AssignedRestaurants = assignments
		}
	}

	return result, nil
}

// Update updates an existing menu
func (r *menuRepository) Update(menu *models.Menu) error {
	query := r.DB.Rebind(`
		UPDATE menus
		SET name = ?, description = ?, menu_config = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
		RETURNING id, name, description, menu_config, is_active, created_at, updated_at
	`)

	args := []interface{}{
		menu.Name,
		menu.Description,
		menu.MenuConfig,
		menu.IsActive,
		menu.ID,
	}

	return GetData(r.DB, query, menu, args)
}

// Delete deletes a menu by ID
func (r *menuRepository) Delete(id int) error {
	query := r.DB.Rebind(`DELETE FROM menus WHERE id = ?`)
	args := []interface{}{id}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to delete menu: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("menu not found")
	}

	return nil
}

// AssignToRestaurant assigns a menu to a restaurant
func (r *menuRepository) AssignToRestaurant(restaurantMenu *models.RestaurantMenu) error {
	query := r.DB.Rebind(`
		INSERT INTO restaurant_menus (restaurant_id, menu_id, is_active, display_order)
		VALUES (?, ?, ?, ?)
		RETURNING id, restaurant_id, menu_id, is_active, display_order, created_at, updated_at
	`)

	args := []interface{}{
		restaurantMenu.RestaurantID,
		restaurantMenu.MenuID,
		restaurantMenu.IsActive,
		restaurantMenu.DisplayOrder,
	}

	return GetData(r.DB, query, restaurantMenu, args)
}

// UnassignFromRestaurant removes menu assignment from restaurant
func (r *menuRepository) UnassignFromRestaurant(restaurantID, menuID int) error {
	query := r.DB.Rebind(`DELETE FROM restaurant_menus WHERE restaurant_id = ? AND menu_id = ?`)
	_, err := r.DB.Exec(query, restaurantID, menuID)
	return err
}

// GetRestaurantMenu retrieves a specific restaurant-menu assignment
func (r *menuRepository) GetRestaurantMenu(restaurantID, menuID int) (*models.RestaurantMenu, error) {
	var rm models.RestaurantMenu
	query := r.DB.Rebind(`SELECT * FROM restaurant_menus WHERE restaurant_id = ? AND menu_id = ?`)

	err := r.DB.QueryRowx(query, restaurantID, menuID).StructScan(&rm)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("menu not assigned to restaurant")
		}
		return nil, fmt.Errorf("failed to get restaurant menu: %w", err)
	}

	return &rm, nil
}

// GetActiveMenuByRestaurantID retrieves the active menu for a restaurant
func (r *menuRepository) GetActiveMenuByRestaurantID(restaurantID int) (*models.Menu, error) {
	var menu models.Menu
	query := r.DB.Rebind(`
		SELECT m.*
		FROM menus m
		JOIN restaurant_menus rm ON m.id = rm.menu_id
		WHERE rm.restaurant_id = ? AND rm.is_active = true
		LIMIT 1
	`)

	err := r.DB.QueryRowx(query, restaurantID).StructScan(&menu)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("no active menu found")
		}
		return nil, fmt.Errorf("failed to get active menu: %w", err)
	}

	return &menu, nil
}

// GetMenusByRestaurantID retrieves all menus for a restaurant
func (r *menuRepository) GetMenusByRestaurantID(restaurantID int) ([]models.Menu, error) {
	menus := make([]models.Menu, 0)
	query := r.DB.Rebind(`
		SELECT m.*
		FROM menus m
		JOIN restaurant_menus rm ON m.id = rm.menu_id
		WHERE rm.restaurant_id = ?
		ORDER BY rm.display_order, m.name
	`)

	err := SelectData(r.DB, query, &menus, []interface{}{restaurantID})
	if err != nil {
		return menus, fmt.Errorf("failed to get menus for restaurant: %w", err)
	}

	return menus, nil
}

// SetActiveMenu sets a menu as active for a restaurant (transaction)
func (r *menuRepository) SetActiveMenu(restaurantID, menuID int) error {
	tx, err := r.DB.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Verify menu is assigned to restaurant
	var exists bool
	checkQuery := tx.Rebind(`SELECT EXISTS(SELECT 1 FROM restaurant_menus WHERE restaurant_id=? AND menu_id=?)`)
	err = tx.QueryRowx(checkQuery, restaurantID, menuID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check menu assignment: %w", err)
	}
	if !exists {
		return fmt.Errorf("menu not assigned to restaurant")
	}

	// Unset all active menus for this restaurant
	unsetQuery := tx.Rebind(`UPDATE restaurant_menus SET is_active=false WHERE restaurant_id=?`)
	_, err = tx.Exec(unsetQuery, restaurantID)
	if err != nil {
		return fmt.Errorf("failed to unset active menus: %w", err)
	}

	// Set specified menu as active
	setQuery := tx.Rebind(`UPDATE restaurant_menus SET is_active=true WHERE restaurant_id=? AND menu_id=?`)
	_, err = tx.Exec(setQuery, restaurantID, menuID)
	if err != nil {
		return fmt.Errorf("failed to set active menu: %w", err)
	}

	return tx.Commit()
}

// IsMenuAssignedToRestaurants checks if menu is assigned to any restaurant
func (r *menuRepository) IsMenuAssignedToRestaurants(menuID int) (bool, int, error) {
	var count int
	query := r.DB.Rebind(`SELECT COUNT(*) FROM restaurant_menus WHERE menu_id = ?`)

	err := r.DB.QueryRowx(query, menuID).Scan(&count)
	if err != nil {
		return false, 0, fmt.Errorf("failed to check menu assignments: %w", err)
	}

	return count > 0, count, nil
}

// DoesRestaurantHaveMenu checks if a restaurant has a specific menu assigned
func (r *menuRepository) DoesRestaurantHaveMenu(restaurantID, menuID int) (bool, error) {
	var exists bool
	query := r.DB.Rebind(`SELECT EXISTS(SELECT 1 FROM restaurant_menus WHERE restaurant_id=? AND menu_id=?)`)

	err := r.DB.QueryRowx(query, restaurantID, menuID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check restaurant menu: %w", err)
	}

	return exists, nil
}

// DoesVendorOwnMenu checks if a vendor owns a menu
func (r *menuRepository) DoesVendorOwnMenu(vendorID, menuID int) (bool, error) {
	var exists bool
	query := r.DB.Rebind(`
		SELECT EXISTS(
			SELECT 1 FROM menus
			WHERE id = ? AND vendor_id = ?
		)
	`)

	err := r.DB.QueryRowx(query, menuID, vendorID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check vendor menu ownership: %w", err)
	}

	return exists, nil
}
