package models

import (
	"delivery_app/backend/models/base"
)

// Menu represents a menu template
type Menu struct {
	base.Timestamps `db:""` // Embedded timestamps (created_at, updated_at)

	ID          int     `json:"id" db:"id"`
	Name        string  `json:"name" db:"name"`
	Description *string `json:"description,omitempty" db:"description"`
	MenuConfig  string  `json:"menu_config" db:"menu_config"` // JSONB as string
	VendorID    *int    `json:"vendor_id,omitempty" db:"vendor_id"` // Vendor who owns this menu
	IsActive    bool    `json:"is_active" db:"is_active"`
}

// RestaurantMenu represents a menu assignment to a restaurant
type RestaurantMenu struct {
	base.Timestamps `db:""` // Embedded timestamps (created_at, updated_at)

	ID           int  `json:"id" db:"id"`
	RestaurantID int  `json:"restaurant_id" db:"restaurant_id"`
	MenuID       int  `json:"menu_id" db:"menu_id"`
	IsActive     bool `json:"is_active" db:"is_active"`
	DisplayOrder int  `json:"display_order" db:"display_order"`
}

// CreateMenuRequest for creating a new menu
type CreateMenuRequest struct {
	Name        string `json:"name" validate:"required,min=1,max=255"`
	Description string `json:"description,omitempty"`
	MenuConfig  string `json:"menu_config" validate:"required"`
	IsActive    bool   `json:"is_active"`
}

// UpdateMenuRequest for updating a menu (all fields optional)
type UpdateMenuRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	MenuConfig  *string `json:"menu_config,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

// AssignMenuRequest for assigning menu to restaurant
type AssignMenuRequest struct {
	IsActive     bool `json:"is_active"`
	DisplayOrder int  `json:"display_order"`
}

// SetActiveMenuRequest for setting active menu
type SetActiveMenuRequest struct {
	MenuID int `json:"menu_id" validate:"required"`
}

// MenuWithRestaurants includes assigned restaurants
type MenuWithRestaurants struct {
	Menu
	AssignedRestaurants []RestaurantMenuAssignment `json:"assigned_restaurants,omitempty"`
}

// RestaurantMenuAssignment shows menu assignment details
type RestaurantMenuAssignment struct {
	RestaurantID   int    `json:"restaurant_id" db:"restaurant_id"`
	RestaurantName string `json:"restaurant_name" db:"restaurant_name"`
	IsActive       bool   `json:"is_active" db:"is_active"`
	DisplayOrder   int    `json:"display_order" db:"display_order"`
}

// RestaurantWithMenu for customer view
type RestaurantWithMenu struct {
	Restaurant Restaurant `json:"restaurant"`
	Menu       Menu       `json:"menu"`
}
