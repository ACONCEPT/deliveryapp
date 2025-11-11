package repositories

import (
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// VendorRestaurantRepository defines the interface for vendor_restaurant data access
type VendorRestaurantRepository interface {
	Create(vendorRestaurant *models.VendorRestaurant) error
	GetByID(id int) (*models.VendorRestaurant, error)
	GetByRestaurantID(restaurantID int) (*models.VendorRestaurant, error)
	GetByVendorID(vendorID int) ([]models.VendorRestaurant, error)
	GetAll() ([]models.VendorRestaurant, error)
	Delete(id int) error
	DeleteByRestaurantID(restaurantID int) error
	TransferOwnership(restaurantID, newVendorID int) error

	// Ownership verification
	IsVendorOwner(restaurantID, vendorID int) (bool, error)
}

// vendorRestaurantRepository implements the VendorRestaurantRepository interface
type vendorRestaurantRepository struct {
	*BaseRepository[models.VendorRestaurant]
	DB *sqlx.DB
}

// NewVendorRestaurantRepository creates a new instance of VendorRestaurantRepository
func NewVendorRestaurantRepository(db *sqlx.DB) VendorRestaurantRepository {
	return &vendorRestaurantRepository{
		BaseRepository: NewBaseRepository[models.VendorRestaurant](db, "vendor_restaurants"),
		DB:             db,
	}
}

// Create inserts a new vendor-restaurant relationship
func (r *vendorRestaurantRepository) Create(vendorRestaurant *models.VendorRestaurant) error {
	query := r.DB.Rebind(`
		INSERT INTO vendor_restaurants (vendor_id, restaurant_id)
		VALUES (?, ?)
		RETURNING id, vendor_id, restaurant_id, created_at, updated_at
	`)

	args := []interface{}{
		vendorRestaurant.VendorID,
		vendorRestaurant.RestaurantID,
	}

	return GetData(r.DB, query, vendorRestaurant, args)
}

// GetByID retrieves a vendor-restaurant relationship by ID
// Inherited from BaseRepository[models.VendorRestaurant]

// GetByRestaurantID retrieves the vendor-restaurant relationship for a specific restaurant
// Uses base repository GetByField for simplified implementation
func (r *vendorRestaurantRepository) GetByRestaurantID(restaurantID int) (*models.VendorRestaurant, error) {
	vendorRestaurant, err := r.GetByField("restaurant_id", restaurantID)
	if err != nil {
		return nil, fmt.Errorf("no vendor found for this restaurant")
	}
	return vendorRestaurant, nil
}

// GetByVendorID retrieves all vendor-restaurant relationships for a specific vendor
func (r *vendorRestaurantRepository) GetByVendorID(vendorID int) ([]models.VendorRestaurant, error) {
	vendorRestaurants := make([]models.VendorRestaurant, 0)
	query := r.DB.Rebind(`
		SELECT * FROM vendor_restaurants
		WHERE vendor_id = ?
		ORDER BY created_at DESC
	`)

	err := SelectData(r.DB, query, &vendorRestaurants, []interface{}{vendorID})
	if err != nil {
		return vendorRestaurants, fmt.Errorf("failed to get vendor-restaurants: %w", err)
	}

	return vendorRestaurants, nil
}

// GetAll retrieves all vendor-restaurant relationships
func (r *vendorRestaurantRepository) GetAll() ([]models.VendorRestaurant, error) {
	vendorRestaurants := make([]models.VendorRestaurant, 0)
	query := `SELECT * FROM vendor_restaurants ORDER BY created_at DESC`

	err := SelectData(r.DB, query, &vendorRestaurants, []interface{}{})
	if err != nil {
		return vendorRestaurants, fmt.Errorf("failed to get vendor-restaurants: %w", err)
	}

	return vendorRestaurants, nil
}

// Delete deletes a vendor-restaurant relationship by ID
// Inherited from BaseRepository[models.VendorRestaurant]

// DeleteByRestaurantID deletes the vendor-restaurant relationship for a specific restaurant
func (r *vendorRestaurantRepository) DeleteByRestaurantID(restaurantID int) error {
	query := r.DB.Rebind(`DELETE FROM vendor_restaurants WHERE restaurant_id = ?`)
	args := []interface{}{restaurantID}

	result, err := ExecuteStatement(r.DB, query, args)
	if err != nil {
		return fmt.Errorf("failed to delete vendor-restaurant: %w", err)
	}

	return CheckRowsAffected(result, "vendor-restaurant relationship")
}

// TransferOwnership transfers restaurant ownership to a new vendor
func (r *vendorRestaurantRepository) TransferOwnership(restaurantID, newVendorID int) error {
	query := r.DB.Rebind(`
		UPDATE vendor_restaurants
		SET vendor_id = ?, updated_at = CURRENT_TIMESTAMP
		WHERE restaurant_id = ?
		RETURNING id, vendor_id, restaurant_id, created_at, updated_at
	`)

	args := []interface{}{newVendorID, restaurantID}

	var vendorRestaurant models.VendorRestaurant
	err := GetData(r.DB, query, &vendorRestaurant, args)
	if err != nil {
		return fmt.Errorf("failed to transfer ownership: %w", err)
	}

	return nil
}

// IsVendorOwner checks if a vendor owns a restaurant
func (r *vendorRestaurantRepository) IsVendorOwner(restaurantID, vendorID int) (bool, error) {
	err := VerifyOwnershipByJunction(r.DB, "vendor_restaurants", "restaurant_id", "vendor_id", restaurantID, vendorID)
	if err != nil {
		// If error is "ownership not found", return false with no error
		if err.Error() == "ownership not found or access denied" {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
