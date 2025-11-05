package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"delivery_app/backend/models/base"
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

	// Driver approval methods
	GetPendingDrivers() ([]models.Driver, error)
	ApproveDriver(driverID, adminID int) error
	RejectDriver(driverID, adminID int, reason string) error
	GetDriverByID(driverID int) (*models.Driver, error)

	// Profile helper methods to reduce duplication
	GetUserProfile(userID int, userType models.UserType) (interface{}, error)
	GetCustomerIDByUserID(userID int) (int, error)
	GetVendorIDByUserID(userID int) (int, error)
	GetDriverIDByUserID(userID int) (int, error)
	GetAdminIDByUserID(userID int) (int, error)

	// User deletion methods
	DeleteUser(userID int) error
	CountAdminUsers() (int, error)

	// User listing and filtering
	GetAllUsers(userType, status, search string, limit, offset int) ([]models.UserWithProfile, int, error)
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
				  approval_status, approved_by_admin_id, approved_at, rejection_reason,
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

// GetPendingDrivers retrieves all drivers with pending approval status
func (r *userRepository) GetPendingDrivers() ([]models.Driver, error) {
	drivers := make([]models.Driver, 0)
	query := `
		SELECT * FROM drivers
		WHERE approval_status = 'pending'
		ORDER BY created_at ASC
	`

	err := SelectData(r.DB, query, &drivers, []interface{}{})
	if err != nil {
		return drivers, fmt.Errorf("failed to get pending drivers: %w", err)
	}

	return drivers, nil
}

// ApproveDriver approves a driver and sets them to available
func (r *userRepository) ApproveDriver(driverID, adminID int) error {
	query := r.DB.Rebind(`
		UPDATE drivers
		SET
			approval_status = 'approved',
			approved_by_admin_id = ?,
			approved_at = CURRENT_TIMESTAMP,
			is_available = true,
			rejection_reason = NULL,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`)

	args := []interface{}{adminID, driverID}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to approve driver: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("driver not found")
	}

	return nil
}

// RejectDriver rejects a driver with a reason
func (r *userRepository) RejectDriver(driverID, adminID int, reason string) error {
	query := r.DB.Rebind(`
		UPDATE drivers
		SET
			approval_status = 'rejected',
			approved_by_admin_id = ?,
			approved_at = CURRENT_TIMESTAMP,
			is_available = false,
			rejection_reason = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`)

	args := []interface{}{adminID, reason, driverID}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to reject driver: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("driver not found")
	}

	return nil
}

// GetDriverByID retrieves a driver by ID
func (r *userRepository) GetDriverByID(driverID int) (*models.Driver, error) {
	var driver models.Driver
	query := r.DB.Rebind(`SELECT * FROM drivers WHERE id = ?`)

	err := r.DB.QueryRowx(query, driverID).StructScan(&driver)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("driver not found")
		}
		return nil, fmt.Errorf("failed to get driver: %w", err)
	}

	return &driver, nil
}

// DeleteUser deletes a user and all associated profile data (cascades to profile tables)
func (r *userRepository) DeleteUser(userID int) error {
	query := r.DB.Rebind(`DELETE FROM users WHERE id = ?`)

	result, err := ExecuteStatement(r.DB, query, []interface{}{userID})
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

// CountAdminUsers returns the total number of admin users in the system
func (r *userRepository) CountAdminUsers() (int, error) {
	var count int
	query := `
		SELECT COUNT(*)
		FROM users
		WHERE user_type = 'admin'
	`

	err := r.DB.QueryRow(query).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count admin users: %w", err)
	}

	return count, nil
}

// GetAllUsers retrieves all users with filtering, searching, and pagination
func (r *userRepository) GetAllUsers(userType, status, search string, limit, offset int) ([]models.UserWithProfile, int, error) {
	users := make([]models.UserWithProfile, 0)

	// Build WHERE clause dynamically
	var whereClauses []string
	var args []interface{}
	argCount := 1

	if userType != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("u.user_type = $%d", argCount))
		args = append(args, userType)
		argCount++
	}

	if status != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("u.status = $%d", argCount))
		args = append(args, status)
		argCount++
	}

	if search != "" {
		// Search across username, email, and profile names
		searchPattern := "%" + search + "%"
		searchClause := fmt.Sprintf(`(
			u.username ILIKE $%d OR
			u.email ILIKE $%d OR
			c.full_name ILIKE $%d OR
			v.business_name ILIKE $%d OR
			d.full_name ILIKE $%d OR
			a.full_name ILIKE $%d
		)`, argCount, argCount, argCount, argCount, argCount, argCount)
		whereClauses = append(whereClauses, searchClause)
		args = append(args, searchPattern)
		argCount++
	}

	whereClause := ""
	if len(whereClauses) > 0 {
		whereClause = "WHERE " + whereClauses[0]
		for i := 1; i < len(whereClauses); i++ {
			whereClause += " AND " + whereClauses[i]
		}
	}

	// Count total matching records
	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT u.id)
		FROM users u
		LEFT JOIN customers c ON u.id = c.user_id
		LEFT JOIN vendors v ON u.id = v.user_id
		LEFT JOIN drivers d ON u.id = d.user_id
		LEFT JOIN admins a ON u.id = a.user_id
		%s
	`, whereClause)

	var totalCount int
	err := r.DB.QueryRow(countQuery, args...).Scan(&totalCount)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count users: %w", err)
	}

	// Fetch paginated users
	args = append(args, limit, offset)
	query := fmt.Sprintf(`
		SELECT
			u.id,
			u.username,
			u.email,
			u.user_type,
			u.status,
			u.created_at,
			u.updated_at,
			-- Customer profile fields
			c.id as customer_id,
			c.full_name as customer_full_name,
			c.phone as customer_phone,
			c.default_address_id,
			c.created_at as customer_created_at,
			c.updated_at as customer_updated_at,
			-- Vendor profile fields
			v.id as vendor_id,
			v.business_name,
			v.description as vendor_description,
			v.phone as vendor_phone,
			v.address_line1 as vendor_address_line1,
			v.address_line2 as vendor_address_line2,
			v.city as vendor_city,
			v.state as vendor_state,
			v.postal_code as vendor_postal_code,
			v.country as vendor_country,
			v.latitude as vendor_latitude,
			v.longitude as vendor_longitude,
			v.is_active as vendor_is_active,
			v.rating as vendor_rating,
			v.total_orders as vendor_total_orders,
			v.approval_status as vendor_approval_status,
			v.approved_by_admin_id as vendor_approved_by_admin_id,
			v.approved_at as vendor_approved_at,
			v.rejection_reason as vendor_rejection_reason,
			v.created_at as vendor_created_at,
			v.updated_at as vendor_updated_at,
			-- Driver profile fields
			d.id as driver_id,
			d.full_name as driver_full_name,
			d.phone as driver_phone,
			d.vehicle_type,
			d.vehicle_plate,
			d.license_number,
			d.is_available,
			d.current_latitude,
			d.current_longitude,
			d.rating as driver_rating,
			d.total_deliveries,
			d.approval_status as driver_approval_status,
			d.approved_by_admin_id as driver_approved_by_admin_id,
			d.approved_at as driver_approved_at,
			d.rejection_reason as driver_rejection_reason,
			d.created_at as driver_created_at,
			d.updated_at as driver_updated_at,
			-- Admin profile fields
			a.id as admin_id,
			a.full_name as admin_full_name,
			a.phone as admin_phone,
			a.role as admin_role,
			a.permissions as admin_permissions,
			a.created_at as admin_created_at,
			a.updated_at as admin_updated_at
		FROM users u
		LEFT JOIN customers c ON u.id = c.user_id
		LEFT JOIN vendors v ON u.id = v.user_id
		LEFT JOIN drivers d ON u.id = d.user_id
		LEFT JOIN admins a ON u.id = a.user_id
		%s
		ORDER BY u.created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argCount, argCount+1)

	rows, err := r.DB.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var user models.UserWithProfile
		var userType models.UserType

		// Customer fields
		var customerID sql.NullInt64
		var customerFullName, customerPhone sql.NullString
		var customerDefaultAddressID sql.NullInt64
		var customerCreatedAt, customerUpdatedAt sql.NullTime

		// Vendor fields
		var vendorID sql.NullInt64
		var businessName, vendorDescription, vendorPhone sql.NullString
		var vendorAddressLine1, vendorAddressLine2, vendorCity, vendorState, vendorPostalCode, vendorCountry sql.NullString
		var vendorLatitude, vendorLongitude sql.NullFloat64
		var vendorIsActive sql.NullBool
		var vendorRating sql.NullFloat64
		var vendorTotalOrders sql.NullInt64
		var vendorApprovalStatus sql.NullString
		var vendorApprovedByAdminID sql.NullInt64
		var vendorApprovedAt sql.NullTime
		var vendorRejectionReason sql.NullString
		var vendorCreatedAt, vendorUpdatedAt sql.NullTime

		// Driver fields
		var driverID sql.NullInt64
		var driverFullName, driverPhone sql.NullString
		var vehicleType, vehiclePlate, licenseNumber sql.NullString
		var isAvailable sql.NullBool
		var currentLatitude, currentLongitude sql.NullFloat64
		var driverRating sql.NullFloat64
		var totalDeliveries sql.NullInt64
		var driverApprovalStatus sql.NullString
		var driverApprovedByAdminID sql.NullInt64
		var driverApprovedAt sql.NullTime
		var driverRejectionReason sql.NullString
		var driverCreatedAt, driverUpdatedAt sql.NullTime

		// Admin fields
		var adminID sql.NullInt64
		var adminFullName, adminPhone, adminRole, adminPermissions sql.NullString
		var adminCreatedAt, adminUpdatedAt sql.NullTime

		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&userType,
			&user.Status,
			&user.CreatedAt,
			&user.UpdatedAt,
			// Customer
			&customerID,
			&customerFullName,
			&customerPhone,
			&customerDefaultAddressID,
			&customerCreatedAt,
			&customerUpdatedAt,
			// Vendor
			&vendorID,
			&businessName,
			&vendorDescription,
			&vendorPhone,
			&vendorAddressLine1,
			&vendorAddressLine2,
			&vendorCity,
			&vendorState,
			&vendorPostalCode,
			&vendorCountry,
			&vendorLatitude,
			&vendorLongitude,
			&vendorIsActive,
			&vendorRating,
			&vendorTotalOrders,
			&vendorApprovalStatus,
			&vendorApprovedByAdminID,
			&vendorApprovedAt,
			&vendorRejectionReason,
			&vendorCreatedAt,
			&vendorUpdatedAt,
			// Driver
			&driverID,
			&driverFullName,
			&driverPhone,
			&vehicleType,
			&vehiclePlate,
			&licenseNumber,
			&isAvailable,
			&currentLatitude,
			&currentLongitude,
			&driverRating,
			&totalDeliveries,
			&driverApprovalStatus,
			&driverApprovedByAdminID,
			&driverApprovedAt,
			&driverRejectionReason,
			&driverCreatedAt,
			&driverUpdatedAt,
			// Admin
			&adminID,
			&adminFullName,
			&adminPhone,
			&adminRole,
			&adminPermissions,
			&adminCreatedAt,
			&adminUpdatedAt,
		)

		if err != nil {
			return nil, 0, fmt.Errorf("failed to scan user row: %w", err)
		}

		user.UserType = userType

		// Build profile based on user type
		switch userType {
		case models.UserTypeCustomer:
			if customerID.Valid {
				customer := &models.Customer{
					Timestamps: base.Timestamps{
						CreatedAt: customerCreatedAt.Time,
						UpdatedAt: customerUpdatedAt.Time,
					},
					ID:       int(customerID.Int64),
					UserID:   user.ID,
					FullName: customerFullName.String,
				}
				if customerPhone.Valid {
					customer.Phone = &customerPhone.String
				}
				if customerDefaultAddressID.Valid {
					defaultAddrID := int(customerDefaultAddressID.Int64)
					customer.DefaultAddressID = &defaultAddrID
				}
				user.Profile = customer
			}

		case models.UserTypeVendor:
			if vendorID.Valid {
				vendor := &models.Vendor{
					Timestamps: base.Timestamps{
						CreatedAt: vendorCreatedAt.Time,
						UpdatedAt: vendorUpdatedAt.Time,
					},
					ApprovableEntity: base.ApprovableEntity{
						ApprovalStatus: base.ApprovalStatus(vendorApprovalStatus.String),
					},
					ID:           int(vendorID.Int64),
					UserID:       user.ID,
					BusinessName: businessName.String,
					IsActive:     vendorIsActive.Bool,
					Rating:       vendorRating.Float64,
					TotalOrders:  int(vendorTotalOrders.Int64),
				}
				if vendorDescription.Valid {
					vendor.Description = &vendorDescription.String
				}
				if vendorPhone.Valid {
					vendor.Phone = &vendorPhone.String
				}
				if vendorAddressLine1.Valid {
					vendor.AddressLine1 = &vendorAddressLine1.String
				}
				if vendorAddressLine2.Valid {
					vendor.AddressLine2 = &vendorAddressLine2.String
				}
				if vendorCity.Valid {
					vendor.City = &vendorCity.String
				}
				if vendorState.Valid {
					vendor.State = &vendorState.String
				}
				if vendorPostalCode.Valid {
					vendor.PostalCode = &vendorPostalCode.String
				}
				if vendorCountry.Valid {
					vendor.Country = &vendorCountry.String
				}
				if vendorLatitude.Valid {
					vendor.Latitude = &vendorLatitude.Float64
				}
				if vendorLongitude.Valid {
					vendor.Longitude = &vendorLongitude.Float64
				}
				if vendorApprovedByAdminID.Valid {
					adminID := int(vendorApprovedByAdminID.Int64)
					vendor.ApprovedByAdminID = &adminID
				}
				if vendorApprovedAt.Valid {
					vendor.ApprovedAt = &vendorApprovedAt.Time
				}
				if vendorRejectionReason.Valid {
					vendor.RejectionReason = &vendorRejectionReason.String
				}
				user.Profile = vendor
			}

		case models.UserTypeDriver:
			if driverID.Valid {
				driver := &models.Driver{
					Timestamps: base.Timestamps{
						CreatedAt: driverCreatedAt.Time,
						UpdatedAt: driverUpdatedAt.Time,
					},
					ApprovableEntity: base.ApprovableEntity{
						ApprovalStatus: base.ApprovalStatus(driverApprovalStatus.String),
					},
					ID:              int(driverID.Int64),
					UserID:          user.ID,
					FullName:        driverFullName.String,
					Phone:           driverPhone.String,
					IsAvailable:     isAvailable.Bool,
					Rating:          driverRating.Float64,
					TotalDeliveries: int(totalDeliveries.Int64),
				}
				if vehicleType.Valid {
					driver.VehicleType = &vehicleType.String
				}
				if vehiclePlate.Valid {
					driver.VehiclePlate = &vehiclePlate.String
				}
				if licenseNumber.Valid {
					driver.LicenseNumber = &licenseNumber.String
				}
				if currentLatitude.Valid {
					driver.CurrentLatitude = &currentLatitude.Float64
				}
				if currentLongitude.Valid {
					driver.CurrentLongitude = &currentLongitude.Float64
				}
				if driverApprovedByAdminID.Valid {
					adminID := int(driverApprovedByAdminID.Int64)
					driver.ApprovedByAdminID = &adminID
				}
				if driverApprovedAt.Valid {
					driver.ApprovedAt = &driverApprovedAt.Time
				}
				if driverRejectionReason.Valid {
					driver.RejectionReason = &driverRejectionReason.String
				}
				user.Profile = driver
			}

		case models.UserTypeAdmin:
			if adminID.Valid {
				admin := &models.Admin{
					Timestamps: base.Timestamps{
						CreatedAt: adminCreatedAt.Time,
						UpdatedAt: adminUpdatedAt.Time,
					},
					ID:       int(adminID.Int64),
					UserID:   user.ID,
					FullName: adminFullName.String,
				}
				if adminPhone.Valid {
					admin.Phone = &adminPhone.String
				}
				if adminRole.Valid {
					admin.Role = &adminRole.String
				}
				if adminPermissions.Valid {
					admin.Permissions = &adminPermissions.String
				}
				user.Profile = admin
			}
		}

		users = append(users, user)
	}

	if err = rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("error iterating user rows: %w", err)
	}

	return users, totalCount, nil
}
