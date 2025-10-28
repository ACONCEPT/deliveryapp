package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// CustomerAddressRepository defines the interface for customer address operations
type CustomerAddressRepository interface {
	Create(address *models.CustomerAddress) error
	GetByID(id int) (*models.CustomerAddress, error)
	GetByCustomerID(customerID int) ([]*models.CustomerAddress, error)
	Update(address *models.CustomerAddress) error
	Delete(id int) error
	SetDefault(customerID, addressID int) error
	GetDefaultByCustomerID(customerID int) (*models.CustomerAddress, error)

	// Ownership verification methods
	VerifyOwnership(addressID, customerID int) error
	GetByIDWithOwnershipCheck(addressID, customerID int) (*models.CustomerAddress, error)
}

// customerAddressRepository implements the CustomerAddressRepository interface
type customerAddressRepository struct {
	DB *sqlx.DB
}

// NewCustomerAddressRepository creates a new instance of CustomerAddressRepository
func NewCustomerAddressRepository(db *sqlx.DB) CustomerAddressRepository {
	return &customerAddressRepository{DB: db}
}

// Create inserts a new customer address
func (r *customerAddressRepository) Create(address *models.CustomerAddress) error {
	query := r.DB.Rebind(`
		INSERT INTO customer_addresses (
			customer_id, address_line1, address_line2, city, state,
			postal_code, country, latitude, longitude, is_default
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		RETURNING id, customer_id, address_line1, address_line2, city, state,
				  postal_code, country, latitude, longitude, is_default, created_at, updated_at
	`)

	args := []interface{}{
		address.CustomerID,
		address.AddressLine1,
		address.AddressLine2,
		address.City,
		address.State,
		address.PostalCode,
		address.Country,
		address.Latitude,
		address.Longitude,
		address.IsDefault,
	}

	return GetData(r.DB, query, address, args)
}

// GetByID retrieves an address by ID
func (r *customerAddressRepository) GetByID(id int) (*models.CustomerAddress, error) {
	var address models.CustomerAddress
	query := r.DB.Rebind(`SELECT * FROM customer_addresses WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&address)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("address not found")
		}
		return nil, fmt.Errorf("failed to get address: %w", err)
	}

	return &address, nil
}

// GetByCustomerID retrieves all addresses for a customer
func (r *customerAddressRepository) GetByCustomerID(customerID int) ([]*models.CustomerAddress, error) {
	// Initialize as empty slice instead of nil to ensure JSON serialization returns [] not null
	addresses := make([]*models.CustomerAddress, 0)
	query := r.DB.Rebind(`
		SELECT * FROM customer_addresses
		WHERE customer_id = ?
		ORDER BY is_default DESC, created_at DESC
	`)

	err := r.DB.Select(&addresses, query, customerID)
	if err != nil {
		return nil, fmt.Errorf("failed to get addresses: %w", err)
	}

	return addresses, nil
}

// Update updates an existing address
func (r *customerAddressRepository) Update(address *models.CustomerAddress) error {
	query := r.DB.Rebind(`
		UPDATE customer_addresses
		SET address_line1 = ?, address_line2 = ?, city = ?, state = ?,
			postal_code = ?, country = ?, latitude = ?, longitude = ?,
			is_default = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?
		RETURNING id, customer_id, address_line1, address_line2, city, state,
				  postal_code, country, latitude, longitude, is_default, created_at, updated_at
	`)

	args := []interface{}{
		address.AddressLine1,
		address.AddressLine2,
		address.City,
		address.State,
		address.PostalCode,
		address.Country,
		address.Latitude,
		address.Longitude,
		address.IsDefault,
		address.ID,
	}

	return GetData(r.DB, query, address, args)
}

// Delete removes an address
func (r *customerAddressRepository) Delete(id int) error {
	query := r.DB.Rebind(`DELETE FROM customer_addresses WHERE id = ?`)

	result, err := r.DB.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete address: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get affected rows: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("address not found")
	}

	return nil
}

// SetDefault sets an address as the default and unsets others
func (r *customerAddressRepository) SetDefault(customerID, addressID int) error {
	tx, err := r.DB.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Unset all defaults for this customer
	unsetQuery := tx.Rebind(`
		UPDATE customer_addresses
		SET is_default = FALSE
		WHERE customer_id = ?
	`)
	_, err = tx.Exec(unsetQuery, customerID)
	if err != nil {
		return fmt.Errorf("failed to unset defaults: %w", err)
	}

	// Set the new default
	setQuery := tx.Rebind(`
		UPDATE customer_addresses
		SET is_default = TRUE
		WHERE id = ? AND customer_id = ?
	`)
	result, err := tx.Exec(setQuery, addressID, customerID)
	if err != nil {
		return fmt.Errorf("failed to set default: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get affected rows: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("address not found or doesn't belong to customer")
	}

	return tx.Commit()
}

// GetDefaultByCustomerID retrieves the default address for a customer
func (r *customerAddressRepository) GetDefaultByCustomerID(customerID int) (*models.CustomerAddress, error) {
	var address models.CustomerAddress
	query := r.DB.Rebind(`
		SELECT * FROM customer_addresses
		WHERE customer_id = ? AND is_default = TRUE
		LIMIT 1
	`)

	err := r.DB.QueryRowx(query, customerID).StructScan(&address)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("no default address found")
		}
		return nil, fmt.Errorf("failed to get default address: %w", err)
	}

	return &address, nil
}

// VerifyOwnership checks if an address belongs to a customer
func (r *customerAddressRepository) VerifyOwnership(addressID, customerID int) error {
	address, err := r.GetByID(addressID)
	if err != nil {
		return err
	}

	if address.CustomerID != customerID {
		return fmt.Errorf("address does not belong to customer")
	}

	return nil
}

// GetByIDWithOwnershipCheck gets address and verifies ownership in one call
func (r *customerAddressRepository) GetByIDWithOwnershipCheck(addressID, customerID int) (*models.CustomerAddress, error) {
	address, err := r.GetByID(addressID)
	if err != nil {
		return nil, err
	}

	if address.CustomerID != customerID {
		return nil, fmt.Errorf("address does not belong to customer")
	}

	return address, nil
}
