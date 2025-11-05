package models

import (
	"delivery_app/backend/models/base"
)

// Restaurant represents a restaurant entity
type Restaurant struct {
	base.Timestamps       `db:""` // Embedded timestamps (created_at, updated_at)
	base.FullAddress      `db:""` // Embedded address fields and geolocation
	base.ApprovableEntity `db:""` // Embedded approval fields

	ID                 int     `json:"id" db:"id"`
	Name               string  `json:"name" db:"name"`
	Description        *string `json:"description,omitempty" db:"description"`
	Phone              *string `json:"phone,omitempty" db:"phone"`
	HoursOfOperation   *string `json:"hours_of_operation,omitempty" db:"hours_of_operation"`
	AveragePrepTimeMin int     `json:"average_prep_time_minutes" db:"average_prep_time_minutes"`
	Timezone           string  `json:"timezone" db:"timezone"`
	IsActive           bool    `json:"is_active" db:"is_active"`
	Rating             float64 `json:"rating" db:"rating"`
	TotalOrders        int     `json:"total_orders" db:"total_orders"`
}

// VendorRestaurant represents the ownership relationship between vendors and restaurants
type VendorRestaurant struct {
	base.Timestamps `db:""` // Embedded timestamps (created_at, updated_at)

	ID           int `json:"id" db:"id"`
	VendorID     int `json:"vendor_id" db:"vendor_id"`
	RestaurantID int `json:"restaurant_id" db:"restaurant_id"`
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
	Latitude           *float64 `json:"latitude,omitempty"`
	Longitude          *float64 `json:"longitude,omitempty"`
	HoursOfOperation   *string  `json:"hours_of_operation,omitempty"`
	AveragePrepTimeMin *int     `json:"average_prep_time_minutes,omitempty"`
	Timezone           *string  `json:"timezone,omitempty"`
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
	Latitude           *float64 `json:"latitude,omitempty"`
	Longitude          *float64 `json:"longitude,omitempty"`
	HoursOfOperation   *string  `json:"hours_of_operation,omitempty"`
	AveragePrepTimeMin *int     `json:"average_prep_time_minutes,omitempty"`
	Timezone           *string  `json:"timezone,omitempty"`
	IsActive           *bool    `json:"is_active,omitempty"`
}
