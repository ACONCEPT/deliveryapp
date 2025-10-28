package models

import "time"

// Restaurant represents a restaurant entity
type Restaurant struct {
	ID                int        `json:"id" db:"id"`
	Name              string     `json:"name" db:"name"`
	Description       *string    `json:"description,omitempty" db:"description"`
	Phone             *string    `json:"phone,omitempty" db:"phone"`
	AddressLine1      *string    `json:"address_line1,omitempty" db:"address_line1"`
	AddressLine2      *string    `json:"address_line2,omitempty" db:"address_line2"`
	City              *string    `json:"city,omitempty" db:"city"`
	State             *string    `json:"state,omitempty" db:"state"`
	PostalCode        *string    `json:"postal_code,omitempty" db:"postal_code"`
	Country           *string    `json:"country,omitempty" db:"country"`
	Latitude          *float64   `json:"latitude,omitempty" db:"latitude"`
	Longitude         *float64   `json:"longitude,omitempty" db:"longitude"`
	HoursOfOperation  *string    `json:"hours_of_operation,omitempty" db:"hours_of_operation"`
	IsActive          bool       `json:"is_active" db:"is_active"`
	Rating            float64    `json:"rating" db:"rating"`
	TotalOrders       int        `json:"total_orders" db:"total_orders"`
	ApprovalStatus    string     `json:"approval_status" db:"approval_status"`
	ApprovedByAdminID *int       `json:"approved_by_admin_id,omitempty" db:"approved_by_admin_id"`
	ApprovedAt        *time.Time `json:"approved_at,omitempty" db:"approved_at"`
	RejectionReason   *string    `json:"rejection_reason,omitempty" db:"rejection_reason"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at" db:"updated_at"`
}

// VendorRestaurant represents the ownership relationship between vendors and restaurants
type VendorRestaurant struct {
	ID           int       `json:"id" db:"id"`
	VendorID     int       `json:"vendor_id" db:"vendor_id"`
	RestaurantID int       `json:"restaurant_id" db:"restaurant_id"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

// RestaurantWithVendor combines restaurant data with vendor information
type RestaurantWithVendor struct {
	Restaurant
	VendorID     int    `json:"vendor_id" db:"vendor_id"`
	BusinessName string `json:"business_name" db:"business_name"`
}

// CreateRestaurantRequest represents the request to create a restaurant
type CreateRestaurantRequest struct {
	Name             string   `json:"name" validate:"required"`
	Description      *string  `json:"description,omitempty"`
	Phone            *string  `json:"phone,omitempty"`
	AddressLine1     *string  `json:"address_line1,omitempty"`
	AddressLine2     *string  `json:"address_line2,omitempty"`
	City             *string  `json:"city,omitempty"`
	State            *string  `json:"state,omitempty"`
	PostalCode       *string  `json:"postal_code,omitempty"`
	Country          *string  `json:"country,omitempty"`
	Latitude         *float64 `json:"latitude,omitempty"`
	Longitude        *float64 `json:"longitude,omitempty"`
	HoursOfOperation *string  `json:"hours_of_operation,omitempty"`
}

// UpdateRestaurantRequest represents the request to update a restaurant
type UpdateRestaurantRequest struct {
	Name             *string  `json:"name,omitempty"`
	Description      *string  `json:"description,omitempty"`
	Phone            *string  `json:"phone,omitempty"`
	AddressLine1     *string  `json:"address_line1,omitempty"`
	AddressLine2     *string  `json:"address_line2,omitempty"`
	City             *string  `json:"city,omitempty"`
	State            *string  `json:"state,omitempty"`
	PostalCode       *string  `json:"postal_code,omitempty"`
	Country          *string  `json:"country,omitempty"`
	Latitude         *float64 `json:"latitude,omitempty"`
	Longitude        *float64 `json:"longitude,omitempty"`
	HoursOfOperation *string  `json:"hours_of_operation,omitempty"`
	IsActive         *bool    `json:"is_active,omitempty"`
}
