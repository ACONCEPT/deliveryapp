package models

import "time"

// UserType represents the type of user in the system
type UserType string

const (
	UserTypeCustomer UserType = "customer"
	UserTypeVendor   UserType = "vendor"
	UserTypeDriver   UserType = "driver"
	UserTypeAdmin    UserType = "admin"
)

// UserStatus represents the status of a user account
type UserStatus string

const (
	UserStatusActive    UserStatus = "active"
	UserStatusInactive  UserStatus = "inactive"
	UserStatusSuspended UserStatus = "suspended"
)

// User represents the main user entity
type User struct {
	ID           int        `json:"id" db:"id"`
	Username     string     `json:"username" db:"username"`
	Email        string     `json:"email" db:"email"`
	PasswordHash string     `json:"-" db:"password_hash"`
	UserType     UserType   `json:"user_type" db:"user_type"`
	UserRole     string     `json:"user_role" db:"user_role"`
	Status       UserStatus `json:"status" db:"status"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// Customer represents a customer profile
type Customer struct {
	ID               int       `json:"id" db:"id"`
	UserID           int       `json:"user_id" db:"user_id"`
	FullName         string    `json:"full_name" db:"full_name"`
	Phone            *string   `json:"phone,omitempty" db:"phone"`
	DefaultAddressID *int      `json:"default_address_id,omitempty" db:"default_address_id"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

// Vendor represents a vendor/restaurant profile
type Vendor struct {
	ID                int        `json:"id" db:"id"`
	UserID            int        `json:"user_id" db:"user_id"`
	BusinessName      string     `json:"business_name" db:"business_name"`
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

// Driver represents a delivery driver profile
type Driver struct {
	ID                int        `json:"id" db:"id"`
	UserID            int        `json:"user_id" db:"user_id"`
	FullName          string     `json:"full_name" db:"full_name"`
	Phone             string     `json:"phone" db:"phone"`
	VehicleType       *string    `json:"vehicle_type,omitempty" db:"vehicle_type"`
	VehiclePlate      *string    `json:"vehicle_plate,omitempty" db:"vehicle_plate"`
	LicenseNumber     *string    `json:"license_number,omitempty" db:"license_number"`
	IsAvailable       bool       `json:"is_available" db:"is_available"`
	CurrentLatitude   *float64   `json:"current_latitude,omitempty" db:"current_latitude"`
	CurrentLongitude  *float64   `json:"current_longitude,omitempty" db:"current_longitude"`
	Rating            float64    `json:"rating" db:"rating"`
	TotalDeliveries   int        `json:"total_deliveries" db:"total_deliveries"`
	ApprovalStatus    string     `json:"approval_status" db:"approval_status"`
	ApprovedByAdminID *int       `json:"approved_by_admin_id,omitempty" db:"approved_by_admin_id"`
	ApprovedAt        *time.Time `json:"approved_at,omitempty" db:"approved_at"`
	RejectionReason   *string    `json:"rejection_reason,omitempty" db:"rejection_reason"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at" db:"updated_at"`
}

// Admin represents an admin profile
type Admin struct {
	ID          int       `json:"id" db:"id"`
	UserID      int       `json:"user_id" db:"user_id"`
	FullName    string    `json:"full_name" db:"full_name"`
	Phone       *string   `json:"phone,omitempty" db:"phone"`
	Role        *string   `json:"role,omitempty" db:"role"`
	Permissions *string   `json:"permissions,omitempty" db:"permissions"` // JSONB stored as string
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// LoginRequest represents the login request payload
type LoginRequest struct {
	Username string `json:"username" validate:"required"`
	Password string `json:"password" validate:"required"`
}

// SignupRequest represents the signup request payload
type SignupRequest struct {
	Username string   `json:"username" validate:"required,min=3,max=50"`
	Email    string   `json:"email" validate:"required,email"`
	Password string   `json:"password" validate:"required,min=6"`
	UserType UserType `json:"user_type" validate:"required,oneof=customer vendor driver admin"`
	FullName string   `json:"full_name" validate:"required"`
	Phone    string   `json:"phone,omitempty"`

	// Vendor-specific fields
	BusinessName string `json:"business_name,omitempty"`
	Description  string `json:"description,omitempty"`

	// Driver-specific fields
	VehicleType   string `json:"vehicle_type,omitempty"`
	VehiclePlate  string `json:"vehicle_plate,omitempty"`
	LicenseNumber string `json:"license_number,omitempty"`
}

// LoginResponse represents the login response payload
type LoginResponse struct {
	Success bool     `json:"success"`
	Message string   `json:"message"`
	Token   string   `json:"token,omitempty"`
	User    *User    `json:"user,omitempty"`
	Profile interface{} `json:"profile,omitempty"`
}

// SignupResponse represents the signup response payload
type SignupResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	UserID  int    `json:"user_id,omitempty"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Error   string `json:"error,omitempty"`
}

// CustomerAddress represents a customer's delivery address
type CustomerAddress struct {
	ID           int       `json:"id" db:"id"`
	CustomerID   int       `json:"customer_id" db:"customer_id"`
	AddressLine1 string    `json:"address_line1" db:"address_line1"`
	AddressLine2 *string   `json:"address_line2,omitempty" db:"address_line2"`
	City         string    `json:"city" db:"city"`
	State        *string   `json:"state,omitempty" db:"state"`
	PostalCode   *string   `json:"postal_code,omitempty" db:"postal_code"`
	Country      string    `json:"country" db:"country"`
	Latitude     *float64  `json:"latitude,omitempty" db:"latitude"`
	Longitude    *float64  `json:"longitude,omitempty" db:"longitude"`
	Timezone     *string   `json:"timezone,omitempty" db:"timezone"`
	IsDefault    bool      `json:"is_default" db:"is_default"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

// CreateAddressRequest represents the request to create a customer address
type CreateAddressRequest struct {
	AddressLine1 string   `json:"address_line1" validate:"required"`
	AddressLine2 *string  `json:"address_line2,omitempty"`
	City         string   `json:"city" validate:"required"`
	State        *string  `json:"state,omitempty"`
	PostalCode   *string  `json:"postal_code,omitempty"`
	Country      string   `json:"country" validate:"required"`
	Latitude     *float64 `json:"latitude,omitempty"`
	Longitude    *float64 `json:"longitude,omitempty"`
	Timezone     *string  `json:"timezone,omitempty"`
	IsDefault    bool     `json:"is_default"`
}

// UpdateAddressRequest represents the request to update a customer address
type UpdateAddressRequest struct {
	AddressLine1 *string  `json:"address_line1,omitempty"`
	AddressLine2 *string  `json:"address_line2,omitempty"`
	City         *string  `json:"city,omitempty"`
	State        *string  `json:"state,omitempty"`
	PostalCode   *string  `json:"postal_code,omitempty"`
	Country      *string  `json:"country,omitempty"`
	Latitude     *float64 `json:"latitude,omitempty"`
	Longitude    *float64 `json:"longitude,omitempty"`
	Timezone     *string  `json:"timezone,omitempty"`
	IsDefault    *bool    `json:"is_default,omitempty"`
}

// UserWithProfile represents a user with their type-specific profile
type UserWithProfile struct {
	ID        int         `json:"id"`
	Username  string      `json:"username"`
	Email     string      `json:"email"`
	UserType  UserType    `json:"user_type"`
	Status    UserStatus  `json:"status"`
	CreatedAt time.Time   `json:"created_at"`
	UpdatedAt time.Time   `json:"updated_at"`
	Profile   interface{} `json:"profile"`
}

// GetAllUsersResponse represents the paginated response for listing users
type GetAllUsersResponse struct {
	Users      []UserWithProfile `json:"users"`
	TotalCount int               `json:"total_count"`
	Page       int               `json:"page"`
	PerPage    int               `json:"per_page"`
	TotalPages int               `json:"total_pages"`
}
