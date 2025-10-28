package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
	"golang.org/x/crypto/bcrypt"
)

// UserRepository defines the interface for user data access
type UserRepository interface {
	Create(user *models.User) error
	GetByUsername(username string) (*models.User, error)
	GetByEmail(email string) (*models.User, error)
	GetByID(id int) (*models.User, error)
	UserExists(username, email string) (bool, error)
	ValidateCredentials(username, password string) (*models.User, error)
	CreateCustomerProfile(userID int, customer *models.Customer) error
	CreateVendorProfile(userID int, vendor *models.Vendor) error
	CreateDriverProfile(userID int, driver *models.Driver) error
	CreateAdminProfile(userID int, admin *models.Admin) error
	GetCustomerByUserID(userID int) (*models.Customer, error)
	GetVendorByUserID(userID int) (*models.Vendor, error)
	GetDriverByUserID(userID int) (*models.Driver, error)
	GetAdminByUserID(userID int) (*models.Admin, error)

	// Vendor approval methods
	GetPendingVendors() ([]models.Vendor, error)
	ApproveVendor(vendorID, adminID int) error
	RejectVendor(vendorID, adminID int, reason string) error
	GetVendorByID(vendorID int) (*models.Vendor, error)

	// Profile helper methods to reduce duplication
	GetUserProfile(userID int, userType models.UserType) (interface{}, error)
	GetCustomerIDByUserID(userID int) (int, error)
	GetVendorIDByUserID(userID int) (int, error)
	GetDriverIDByUserID(userID int) (int, error)
	GetAdminIDByUserID(userID int) (int, error)
}

// userRepository implements the UserRepository interface
type userRepository struct {
	DB *sqlx.DB
}

// NewUserRepository creates a new instance of UserRepository
func NewUserRepository(db *sqlx.DB) UserRepository {
	return &userRepository{DB: db}
}

// Create inserts a new user into the database with hashed password
func (r *userRepository) Create(user *models.User) error {
	// Hash the password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.PasswordHash), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	query := r.DB.Rebind(`
		INSERT INTO users (username, email, password_hash, user_type, status)
		VALUES (?, ?, ?, ?, ?)
		RETURNING id, username, email, password_hash, user_type, status, created_at, updated_at
	`)

	args := []interface{}{
		user.Username,
		user.Email,
		string(hashedPassword),
		user.UserType,
		models.UserStatusActive,
	}

	return GetData(r.DB, query, user, args)
}

// GetByUsername retrieves a user by username
func (r *userRepository) GetByUsername(username string) (*models.User, error) {
	var user models.User
	query := r.DB.Rebind(`SELECT * FROM users WHERE username = ?`)

	err := r.DB.QueryRowx(query, username).StructScan(&user)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

// GetByEmail retrieves a user by email
func (r *userRepository) GetByEmail(email string) (*models.User, error) {
	var user models.User
	query := r.DB.Rebind(`SELECT * FROM users WHERE email = ?`)

	err := r.DB.QueryRowx(query, email).StructScan(&user)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

// GetByID retrieves a user by ID
func (r *userRepository) GetByID(id int) (*models.User, error) {
	var user models.User
	query := r.DB.Rebind(`SELECT * FROM users WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&user)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

// UserExists checks if a user with the given username or email already exists
func (r *userRepository) UserExists(username, email string) (bool, error) {
	var count int
	query := r.DB.Rebind(`SELECT COUNT(*) FROM users WHERE username = ? OR email = ?`)

	err := r.DB.QueryRow(query, username, email).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to check user existence: %w", err)
	}

	return count > 0, nil
}

// ValidateCredentials checks if the provided username and password are valid
func (r *userRepository) ValidateCredentials(username, password string) (*models.User, error) {
	user, err := r.GetByUsername(username)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Compare passwords
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Check if user is active
	if user.Status != models.UserStatusActive {
		return nil, fmt.Errorf("user account is not active")
	}

	return user, nil
}

// CreateCustomerProfile creates a customer profile for a user
func (r *userRepository) CreateCustomerProfile(userID int, customer *models.Customer) error {
	query := r.DB.Rebind(`
		INSERT INTO customers (user_id, full_name, phone)
		VALUES (?, ?, ?)
		RETURNING id, user_id, full_name, phone, default_address_id, created_at, updated_at
	`)

	args := []interface{}{
		userID,
		customer.FullName,
		customer.Phone,
	}

	return GetData(r.DB, query, customer, args)
}

// CreateVendorProfile creates a vendor profile for a user
func (r *userRepository) CreateVendorProfile(userID int, vendor *models.Vendor) error {
	query := r.DB.Rebind(`
		INSERT INTO vendors (user_id, business_name, description, phone)
		VALUES (?, ?, ?, ?)
		RETURNING id, user_id, business_name, description, phone, address_line1, address_line2,
				  city, state, postal_code, country, latitude, longitude, is_active,
				  rating, total_orders, approval_status, approved_by_admin_id, approved_at,
				  rejection_reason, created_at, updated_at
	`)

	args := []interface{}{
		userID,
		vendor.BusinessName,
		vendor.Description,
		vendor.Phone,
	}

	return GetData(r.DB, query, vendor, args)
}

// CreateDriverProfile creates a driver profile for a user
func (r *userRepository) CreateDriverProfile(userID int, driver *models.Driver) error {
	query := r.DB.Rebind(`
		INSERT INTO drivers (user_id, full_name, phone, vehicle_type, vehicle_plate, license_number)
		VALUES (?, ?, ?, ?, ?, ?)
		RETURNING id, user_id, full_name, phone, vehicle_type, vehicle_plate, license_number,
				  is_available, current_latitude, current_longitude, rating, total_deliveries,
				  created_at, updated_at
	`)

	args := []interface{}{
		userID,
		driver.FullName,
		driver.Phone,
		driver.VehicleType,
		driver.VehiclePlate,
		driver.LicenseNumber,
	}

	return GetData(r.DB, query, driver, args)
}

// CreateAdminProfile creates an admin profile for a user
func (r *userRepository) CreateAdminProfile(userID int, admin *models.Admin) error {
	query := r.DB.Rebind(`
		INSERT INTO admins (user_id, full_name, phone, role)
		VALUES (?, ?, ?, ?)
		RETURNING id, user_id, full_name, phone, role, permissions, created_at, updated_at
	`)

	args := []interface{}{
		userID,
		admin.FullName,
		admin.Phone,
		admin.Role,
	}

	return GetData(r.DB, query, admin, args)
}

// GetCustomerByUserID retrieves a customer profile by user ID
func (r *userRepository) GetCustomerByUserID(userID int) (*models.Customer, error) {
	var customer models.Customer
	query := r.DB.Rebind(`SELECT * FROM customers WHERE user_id = ?`)

	err := r.DB.QueryRowx(query, userID).StructScan(&customer)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("customer profile not found")
		}
		return nil, fmt.Errorf("failed to get customer: %w", err)
	}

	return &customer, nil
}

// GetVendorByUserID retrieves a vendor profile by user ID
func (r *userRepository) GetVendorByUserID(userID int) (*models.Vendor, error) {
	var vendor models.Vendor
	query := r.DB.Rebind(`SELECT * FROM vendors WHERE user_id = ?`)

	err := r.DB.QueryRowx(query, userID).StructScan(&vendor)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("vendor profile not found")
		}
		return nil, fmt.Errorf("failed to get vendor: %w", err)
	}

	return &vendor, nil
}

// GetDriverByUserID retrieves a driver profile by user ID
func (r *userRepository) GetDriverByUserID(userID int) (*models.Driver, error) {
	var driver models.Driver
	query := r.DB.Rebind(`SELECT * FROM drivers WHERE user_id = ?`)

	err := r.DB.QueryRowx(query, userID).StructScan(&driver)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("driver profile not found")
		}
		return nil, fmt.Errorf("failed to get driver: %w", err)
	}

	return &driver, nil
}

// GetAdminByUserID retrieves an admin profile by user ID
func (r *userRepository) GetAdminByUserID(userID int) (*models.Admin, error) {
	var admin models.Admin
	query := r.DB.Rebind(`SELECT * FROM admins WHERE user_id = ?`)

	err := r.DB.QueryRowx(query, userID).StructScan(&admin)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("admin profile not found")
		}
		return nil, fmt.Errorf("failed to get admin: %w", err)
	}

	return &admin, nil
}

// GetPendingVendors retrieves all vendors with pending approval status
func (r *userRepository) GetPendingVendors() ([]models.Vendor, error) {
	vendors := make([]models.Vendor, 0)
	query := `
		SELECT * FROM vendors
		WHERE approval_status = 'pending'
		ORDER BY created_at ASC
	`

	err := SelectData(r.DB, query, &vendors, []interface{}{})
	if err != nil {
		return vendors, fmt.Errorf("failed to get pending vendors: %w", err)
	}

	return vendors, nil
}

// ApproveVendor approves a vendor and sets it to active
func (r *userRepository) ApproveVendor(vendorID, adminID int) error {
	query := r.DB.Rebind(`
		UPDATE vendors
		SET
			approval_status = 'approved',
			approved_by_admin_id = ?,
			approved_at = CURRENT_TIMESTAMP,
			is_active = true,
			rejection_reason = NULL,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`)

	args := []interface{}{adminID, vendorID}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to approve vendor: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("vendor not found")
	}

	return nil
}

// RejectVendor rejects a vendor with a reason
func (r *userRepository) RejectVendor(vendorID, adminID int, reason string) error {
	query := r.DB.Rebind(`
		UPDATE vendors
		SET
			approval_status = 'rejected',
			approved_by_admin_id = ?,
			approved_at = CURRENT_TIMESTAMP,
			is_active = false,
			rejection_reason = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`)

	args := []interface{}{adminID, reason, vendorID}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to reject vendor: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("vendor not found")
	}

	return nil
}

// GetVendorByID retrieves a vendor by ID
func (r *userRepository) GetVendorByID(vendorID int) (*models.Vendor, error) {
	var vendor models.Vendor
	query := r.DB.Rebind(`SELECT * FROM vendors WHERE id = ?`)

	err := r.DB.QueryRowx(query, vendorID).StructScan(&vendor)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("vendor not found")
		}
		return nil, fmt.Errorf("failed to get vendor: %w", err)
	}

	return &vendor, nil
}

// GetUserProfile retrieves the type-specific profile for a user
// This consolidates the switch statement that appears in multiple handlers
func (r *userRepository) GetUserProfile(userID int, userType models.UserType) (interface{}, error) {
	switch userType {
	case models.UserTypeCustomer:
		return r.GetCustomerByUserID(userID)
	case models.UserTypeVendor:
		return r.GetVendorByUserID(userID)
	case models.UserTypeDriver:
		return r.GetDriverByUserID(userID)
	case models.UserTypeAdmin:
		return r.GetAdminByUserID(userID)
	default:
		return nil, fmt.Errorf("invalid user type: %s", userType)
	}
}

// GetCustomerIDByUserID gets the customer profile ID from user ID
func (r *userRepository) GetCustomerIDByUserID(userID int) (int, error) {
	customer, err := r.GetCustomerByUserID(userID)
	if err != nil {
		return 0, err
	}
	return customer.ID, nil
}

// GetVendorIDByUserID gets the vendor profile ID from user ID
func (r *userRepository) GetVendorIDByUserID(userID int) (int, error) {
	vendor, err := r.GetVendorByUserID(userID)
	if err != nil {
		return 0, err
	}
	return vendor.ID, nil
}

// GetDriverIDByUserID gets the driver profile ID from user ID
func (r *userRepository) GetDriverIDByUserID(userID int) (int, error) {
	driver, err := r.GetDriverByUserID(userID)
	if err != nil {
		return 0, err
	}
	return driver.ID, nil
}

// GetAdminIDByUserID gets the admin profile ID from user ID
func (r *userRepository) GetAdminIDByUserID(userID int) (int, error) {
	admin, err := r.GetAdminByUserID(userID)
	if err != nil {
		return 0, err
	}
	return admin.ID, nil
}
