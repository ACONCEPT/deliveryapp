package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"net/http"
	"strconv"
)

// CreateAddress handles creating a new customer address
func (h *Handler) CreateAddress(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID using repository helper
	customerID, err := h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Only customers can create addresses")
		return
	}

	// Decode request
	var req models.CreateAddressRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Create address model
	address := &models.CustomerAddress{
		CustomerID:   customerID,
		AddressLine1: req.AddressLine1,
		AddressLine2: req.AddressLine2,
		City:         req.City,
		State:        req.State,
		PostalCode:   req.PostalCode,
		Country:      req.Country,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		IsDefault:    req.IsDefault,
	}

	// If this is set as default, handle the default logic
	if req.IsDefault {
		// Get existing addresses
		existingAddresses, _ := h.App.Deps.Addresses.GetByCustomerID(customerID)
		// If there are existing addresses, we'll handle setting default after creation
		if len(existingAddresses) > 0 {
			address.IsDefault = false // Temporarily set to false, will update after
		}
	}

	// Create address
	if err := h.App.Deps.Addresses.Create(address); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create address", err)
		return
	}

	// If was requested as default, set it
	if req.IsDefault {
		if err := h.App.Deps.Addresses.SetDefault(customerID, address.ID); err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Address created but failed to set as default", err)
			return
		}
		address.IsDefault = true
	}

	// Send response
	sendJSON(w, http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Address created successfully",
		"address": address,
	})
}

// GetAddresses retrieves all addresses for a customer
// Accessible by: the customer themselves, vendors, drivers, and admins
func (h *Handler) GetAddresses(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Determine which customer's addresses to retrieve
	var customerID int
	var err error

	// If user is a customer, get their own addresses
	if user.UserType == models.UserTypeCustomer {
		customerID, err = h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Customer profile not found")
			return
		}
	} else if user.UserType == models.UserTypeVendor || user.UserType == models.UserTypeDriver || user.UserType == models.UserTypeAdmin {
		// For vendors, drivers, and admins, get customer_id from query parameter
		customerIDStr := r.URL.Query().Get("customer_id")
		if customerIDStr == "" {
			sendError(w, http.StatusBadRequest, "customer_id query parameter is required")
			return
		}
		customerID, err = strconv.Atoi(customerIDStr)
		if err != nil {
			sendError(w, http.StatusBadRequest, "Invalid customer_id")
			return
		}
	} else {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Get addresses
	addresses, err := h.App.Deps.Addresses.GetByCustomerID(customerID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve addresses", err)
		return
	}

	// Send response
	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":   true,
		"addresses": addresses,
	})
}

// GetAddress retrieves a specific address by ID
// Accessible by: the customer who owns it, vendors, drivers, and admins
func (h *Handler) GetAddress(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get address ID from URL using helper
	addressID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Get address
	address, err := h.App.Deps.Addresses.GetByID(addressID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Address not found")
		return
	}

	// Verify access permissions
	// Customers can only view their own addresses
	if user.UserType == models.UserTypeCustomer {
		customerID, err := h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Customer profile not found")
			return
		}
		if address.CustomerID != customerID {
			sendError(w, http.StatusForbidden, "You don't have permission to access this address")
			return
		}
	} else if user.UserType != models.UserTypeVendor && user.UserType != models.UserTypeDriver && user.UserType != models.UserTypeAdmin {
		// Only customers, vendors, drivers, and admins can access addresses
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Send response
	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"address": address,
	})
}

// UpdateAddress updates an existing address
func (h *Handler) UpdateAddress(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID using repository helper
	customerID, err := h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Only customers can update addresses")
		return
	}

	// Get address ID from URL using helper
	addressID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Get existing address with ownership check
	address, err := h.App.Deps.Addresses.GetByIDWithOwnershipCheck(addressID, customerID)
	if err != nil {
		sendError(w, http.StatusForbidden, err.Error())
		return
	}

	// Decode request
	var req models.UpdateAddressRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Update fields if provided
	if req.AddressLine1 != nil {
		address.AddressLine1 = *req.AddressLine1
	}
	if req.AddressLine2 != nil {
		address.AddressLine2 = req.AddressLine2
	}
	if req.City != nil {
		address.City = *req.City
	}
	if req.State != nil {
		address.State = req.State
	}
	if req.PostalCode != nil {
		address.PostalCode = req.PostalCode
	}
	if req.Country != nil {
		address.Country = *req.Country
	}
	if req.Latitude != nil {
		address.Latitude = req.Latitude
	}
	if req.Longitude != nil {
		address.Longitude = req.Longitude
	}
	if req.IsDefault != nil && *req.IsDefault {
		// Handle setting as default
		if err := h.App.Deps.Addresses.SetDefault(customerID, addressID); err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to set as default", err)
			return
		}
		address.IsDefault = true
	}

	// Update address
	if err := h.App.Deps.Addresses.Update(address); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update address", err)
		return
	}

	// Send response
	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Address updated successfully",
		"address": address,
	})
}

// DeleteAddress deletes an address
func (h *Handler) DeleteAddress(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID using repository helper
	customerID, err := h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Only customers can delete addresses")
		return
	}

	// Get address ID from URL using helper
	addressID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Verify ownership using repository method
	if err := h.App.Deps.Addresses.VerifyOwnership(addressID, customerID); err != nil {
		sendError(w, http.StatusForbidden, err.Error())
		return
	}

	// Delete address
	if err := h.App.Deps.Addresses.Delete(addressID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete address", err)
		return
	}

	// Send response
	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Address deleted successfully",
	})
}

// SetDefaultAddress sets an address as the default
func (h *Handler) SetDefaultAddress(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID using repository helper
	customerID, err := h.App.Deps.Users.GetCustomerIDByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Only customers can set default addresses")
		return
	}

	// Get address ID from URL using helper
	addressID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Verify ownership using repository method
	if err := h.App.Deps.Addresses.VerifyOwnership(addressID, customerID); err != nil {
		sendError(w, http.StatusForbidden, err.Error())
		return
	}

	// Set as default
	if err := h.App.Deps.Addresses.SetDefault(customerID, addressID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to set default address", err)
		return
	}

	// Send response
	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Default address updated successfully",
	})
}