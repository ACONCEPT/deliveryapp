package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// Approval configuration for restaurants
var restaurantApprovalConfig = ApprovalConfig{
	TableName:          "restaurants",
	IDColumn:           "id",
	ApprovalStatusCol:  "approval_status",
	ApprovedByCol:      "approved_by_admin_id",
	ApprovedAtCol:      "approved_at",
	IsActiveCol:        "is_active",
	RejectionReasonCol: "rejection_reason",
}

// RestaurantRepository defines the interface for restaurant data access
type RestaurantRepository interface {
	Create(restaurant *models.Restaurant) error
	GetByID(id int) (*models.Restaurant, error)
	GetAll() ([]models.Restaurant, error)
	GetByVendorID(vendorID int) ([]models.Restaurant, error)
	GetWithVendorInfo() ([]models.RestaurantWithVendor, error)
	Update(restaurant *models.Restaurant) error
	Delete(id int) error

	// Restaurant approval methods
	GetPendingRestaurants() ([]models.Restaurant, error)
	GetApprovedRestaurants() ([]models.Restaurant, error)
	ApproveRestaurant(restaurantID, adminID int) error
	RejectRestaurant(restaurantID, adminID int, reason string) error

	// Transaction methods
	CreateWithVendor(restaurant *models.Restaurant, vendorID int) error

	// Ownership verification methods
	VerifyVendorOwnership(restaurantID, vendorID int) error
	GetByIDWithOwnershipCheck(restaurantID, vendorID int) (*models.Restaurant, error)

	// Vendor settings methods
	UpdateRestaurantSettings(restaurantID int, hoursOfOperation *string, avgPrepTime *int) error
	UpdateRestaurantPrepTime(restaurantID int, avgPrepTime int) error
}

// restaurantRepository implements the RestaurantRepository interface
type restaurantRepository struct {
	DB *sqlx.DB
}

// NewRestaurantRepository creates a new instance of RestaurantRepository
func NewRestaurantRepository(db *sqlx.DB) RestaurantRepository {
	return &restaurantRepository{DB: db}
}

// Create inserts a new restaurant into the database
func (r *restaurantRepository) Create(restaurant *models.Restaurant) error {
	// Default timezone to UTC if not specified
	if restaurant.Timezone == "" {
		restaurant.Timezone = "UTC"
	}

	query := r.DB.Rebind(`
		INSERT INTO restaurants (name, description, phone, address_line1, address_line2,
		                        city, state, postal_code, country, latitude, longitude,
		                        hours_of_operation, average_prep_time_minutes, timezone, is_active)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		RETURNING id, name, description, phone, address_line1, address_line2, city, state,
		          postal_code, country, latitude, longitude, hours_of_operation,
		          average_prep_time_minutes, timezone, is_active, rating, total_orders,
		          approval_status, approved_by_admin_id, approved_at, rejection_reason,
		          created_at, updated_at
	`)

	err := r.DB.QueryRowx(query,
		restaurant.Name,
		restaurant.Description,
		restaurant.Phone,
		restaurant.AddressLine1,
		restaurant.AddressLine2,
		restaurant.City,
		restaurant.State,
		restaurant.PostalCode,
		restaurant.Country,
		restaurant.Latitude,
		restaurant.Longitude,
		restaurant.HoursOfOperation,
		restaurant.AveragePrepTimeMin,
		restaurant.Timezone,
		restaurant.IsActive,
	).StructScan(restaurant)

	if err != nil {
		return fmt.Errorf("failed to create restaurant: %w", err)
	}

	return nil
}

// GetByID retrieves a restaurant by ID
func (r *restaurantRepository) GetByID(id int) (*models.Restaurant, error) {
	var restaurant models.Restaurant
	query := r.DB.Rebind(`SELECT * FROM restaurants WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&restaurant)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("restaurant not found")
		}
		return nil, fmt.Errorf("failed to get restaurant: %w", err)
	}

	return &restaurant, nil
}

// GetAll retrieves all restaurants
func (r *restaurantRepository) GetAll() ([]models.Restaurant, error) {
	restaurants := make([]models.Restaurant, 0)
	query := `SELECT * FROM restaurants ORDER BY name ASC`

	err := r.DB.Select(&restaurants, query)
	if err != nil {
		return restaurants, fmt.Errorf("failed to get restaurants: %w", err)
	}

	return restaurants, nil
}

// GetByVendorID retrieves all restaurants owned by a specific vendor
func (r *restaurantRepository) GetByVendorID(vendorID int) ([]models.Restaurant, error) {
	restaurants := make([]models.Restaurant, 0)
	query := r.DB.Rebind(`
		SELECT r.*
		FROM restaurants r
		INNER JOIN vendor_restaurants vr ON r.id = vr.restaurant_id
		WHERE vr.vendor_id = ?
		ORDER BY r.name ASC
	`)

	err := r.DB.Select(&restaurants, query, vendorID)
	if err != nil {
		return restaurants, fmt.Errorf("failed to get restaurants by vendor: %w", err)
	}

	return restaurants, nil
}

// GetWithVendorInfo retrieves all restaurants with their vendor information
func (r *restaurantRepository) GetWithVendorInfo() ([]models.RestaurantWithVendor, error) {
	restaurants := make([]models.RestaurantWithVendor, 0)
	query := `
		SELECT r.*, vr.vendor_id, v.business_name
		FROM restaurants r
		LEFT JOIN vendor_restaurants vr ON r.id = vr.restaurant_id
		LEFT JOIN vendors v ON vr.vendor_id = v.id
		ORDER BY r.name ASC
	`

	err := r.DB.Select(&restaurants, query)
	if err != nil {
		return restaurants, fmt.Errorf("failed to get restaurants with vendor info: %w", err)
	}

	return restaurants, nil
}

// Update updates an existing restaurant
func (r *restaurantRepository) Update(restaurant *models.Restaurant) error {
	query := r.DB.Rebind(`
		UPDATE restaurants
		SET name = ?, description = ?, phone = ?, address_line1 = ?, address_line2 = ?,
		    city = ?, state = ?, postal_code = ?, country = ?, latitude = ?, longitude = ?,
		    hours_of_operation = ?, average_prep_time_minutes = ?, is_active = ?,
		    updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
		RETURNING id, name, description, phone, address_line1, address_line2, city, state,
		          postal_code, country, latitude, longitude, hours_of_operation,
		          average_prep_time_minutes, is_active, rating, total_orders,
		          approval_status, approved_by_admin_id, approved_at, rejection_reason,
		          created_at, updated_at
	`)

	err := r.DB.QueryRowx(query,
		restaurant.Name,
		restaurant.Description,
		restaurant.Phone,
		restaurant.AddressLine1,
		restaurant.AddressLine2,
		restaurant.City,
		restaurant.State,
		restaurant.PostalCode,
		restaurant.Country,
		restaurant.Latitude,
		restaurant.Longitude,
		restaurant.HoursOfOperation,
		restaurant.AveragePrepTimeMin,
		restaurant.IsActive,
		restaurant.ID,
	).StructScan(restaurant)

	if err != nil {
		return fmt.Errorf("failed to update restaurant: %w", err)
	}

	return nil
}

// Delete deletes a restaurant by ID
func (r *restaurantRepository) Delete(id int) error {
	query := r.DB.Rebind(`DELETE FROM restaurants WHERE id = ?`)

	result, err := r.DB.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete restaurant: %w", err)
	}

	return CheckRowsAffected(result, "restaurant")
}

// GetPendingRestaurants retrieves all restaurants with pending approval status
func (r *restaurantRepository) GetPendingRestaurants() ([]models.Restaurant, error) {
	restaurants := make([]models.Restaurant, 0)
	query := `
		SELECT * FROM restaurants
		WHERE approval_status = 'pending'
		ORDER BY created_at ASC
	`

	err := r.DB.Select(&restaurants, query)
	if err != nil {
		return restaurants, fmt.Errorf("failed to get pending restaurants: %w", err)
	}

	return restaurants, nil
}

// GetApprovedRestaurants retrieves all approved and active restaurants
func (r *restaurantRepository) GetApprovedRestaurants() ([]models.Restaurant, error) {
	restaurants := make([]models.Restaurant, 0)
	query := `
		SELECT * FROM restaurants
		WHERE approval_status = 'approved' AND is_active = true
		ORDER BY name ASC
	`

	err := r.DB.Select(&restaurants, query)
	if err != nil {
		return restaurants, fmt.Errorf("failed to get approved restaurants: %w", err)
	}

	return restaurants, nil
}

// ApproveRestaurant approves a restaurant and sets it to active
func (r *restaurantRepository) ApproveRestaurant(restaurantID, adminID int) error {
	return ApproveEntity(r.DB, restaurantApprovalConfig, restaurantID, adminID)
}

// RejectRestaurant rejects a restaurant with a reason
func (r *restaurantRepository) RejectRestaurant(restaurantID, adminID int, reason string) error {
	return RejectEntity(r.DB, restaurantApprovalConfig, restaurantID, adminID, reason)
}

// CreateWithVendor creates a restaurant and vendor relationship in a transaction
func (r *restaurantRepository) CreateWithVendor(restaurant *models.Restaurant, vendorID int) error {
	return WithTransaction(r.DB, func(tx *sqlx.Tx) error {
		// Create the restaurant
		query := tx.Rebind(`
			INSERT INTO restaurants (name, description, phone, address_line1, address_line2,
			                        city, state, postal_code, country, latitude, longitude,
			                        hours_of_operation, average_prep_time_minutes, is_active)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			RETURNING id, name, description, phone, address_line1, address_line2, city, state,
			          postal_code, country, latitude, longitude, hours_of_operation,
			          average_prep_time_minutes, is_active, rating, total_orders,
			          approval_status, approved_by_admin_id, approved_at, rejection_reason,
			          created_at, updated_at
		`)

		err := tx.QueryRowx(query,
			restaurant.Name,
			restaurant.Description,
			restaurant.Phone,
			restaurant.AddressLine1,
			restaurant.AddressLine2,
			restaurant.City,
			restaurant.State,
			restaurant.PostalCode,
			restaurant.Country,
			restaurant.Latitude,
			restaurant.Longitude,
			restaurant.HoursOfOperation,
			restaurant.AveragePrepTimeMin,
			restaurant.IsActive,
		).StructScan(restaurant)
		if err != nil {
			return fmt.Errorf("failed to create restaurant: %w", err)
		}

		// Create vendor-restaurant relationship
		vrQuery := tx.Rebind(`
			INSERT INTO vendor_restaurants (vendor_id, restaurant_id)
			VALUES (?, ?)
		`)

		_, err = tx.Exec(vrQuery, vendorID, restaurant.ID)
		if err != nil {
			return fmt.Errorf("failed to create vendor-restaurant relationship: %w", err)
		}

		return nil
	})
}

// VerifyVendorOwnership checks if a restaurant belongs to a vendor
func (r *restaurantRepository) VerifyVendorOwnership(restaurantID, vendorID int) error {
	return VerifyOwnershipByJunction(r.DB, "vendor_restaurants", "restaurant_id", "vendor_id", restaurantID, vendorID)
}

// GetByIDWithOwnershipCheck gets restaurant and verifies vendor ownership
func (r *restaurantRepository) GetByIDWithOwnershipCheck(restaurantID, vendorID int) (*models.Restaurant, error) {
	// First verify ownership
	if err := r.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
		return nil, err
	}

	// Then get the restaurant
	return r.GetByID(restaurantID)
}

// UpdateRestaurantSettings updates restaurant hours of operation and/or average prep time
func (r *restaurantRepository) UpdateRestaurantSettings(restaurantID int, hoursOfOperation *string, avgPrepTime *int) error {
	// Build dynamic query based on what's being updated
	updates := []string{}
	args := []interface{}{}

	if hoursOfOperation != nil {
		updates = append(updates, "hours_of_operation = ?")
		args = append(args, *hoursOfOperation)
	}

	if avgPrepTime != nil {
		updates = append(updates, "average_prep_time_minutes = ?")
		args = append(args, *avgPrepTime)
	}

	if len(updates) == 0 {
		return fmt.Errorf("no fields to update")
	}

	// Add updated_at timestamp
	updates = append(updates, "updated_at = CURRENT_TIMESTAMP")

	// Add restaurant ID to args
	args = append(args, restaurantID)

	query := fmt.Sprintf(`
		UPDATE restaurants
		SET %s
		WHERE id = ?
	`, joinStrings(updates, ", "))

	query = r.DB.Rebind(query)

	result, err := r.DB.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update restaurant settings: %w", err)
	}

	return CheckRowsAffected(result, "restaurant")
}

// UpdateRestaurantPrepTime updates only the average prep time for a restaurant
func (r *restaurantRepository) UpdateRestaurantPrepTime(restaurantID int, avgPrepTime int) error {
	query := r.DB.Rebind(`
		UPDATE restaurants
		SET average_prep_time_minutes = ?,
		    updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
	`)

	result, err := r.DB.Exec(query, avgPrepTime, restaurantID)
	if err != nil {
		return fmt.Errorf("failed to update prep time: %w", err)
	}

	return CheckRowsAffected(result, "restaurant")
}

// joinStrings is a helper function to join strings with a separator
func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}
