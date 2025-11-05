package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"delivery_app/backend/models/base"
	"delivery_app/backend/utils"
	"encoding/json"
	"log"
	"net/http"
)

// CreateRestaurant handles creating a new restaurant
// Only approved vendors can create restaurants, and ownership is automatically assigned
func (h *Handler) CreateRestaurant(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor ID using repository helper
	vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Vendor profile not found")
		return
	}

	// Get full vendor profile to check approval status
	vendor, err := h.App.Deps.Users.GetVendorByID(vendorID)
	if err != nil {
		sendError(w, http.StatusForbidden, "Vendor profile not found")
		return
	}

	// Check if vendor is approved
	if vendor.ApprovalStatus != base.ApprovalStatusApproved {
		var message string
		if vendor.ApprovalStatus == base.ApprovalStatusPending {
			message = "Your vendor account is pending approval. You cannot create restaurants until approved by an administrator."
		} else if vendor.ApprovalStatus == base.ApprovalStatusRejected {
			rejectionMsg := "Your vendor account has been rejected."
			if vendor.RejectionReason != nil {
				rejectionMsg += " Reason: " + *vendor.RejectionReason
			}
			message = rejectionMsg
		} else {
			message = "Your vendor account is not approved. Please contact support."
		}
		sendError(w, http.StatusForbidden, message)
		return
	}

	// Decode request
	var req models.CreateRestaurantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Create restaurant model - will be set to pending by default via database migration
	restaurant := &models.Restaurant{
		FullAddress: base.FullAddress{
			AddressFields: base.AddressFields{
				AddressLine1: req.AddressLine1,
				AddressLine2: req.AddressLine2,
				City:         req.City,
				State:        req.State,
				PostalCode:   req.PostalCode,
				Country:      req.Country,
			},
			GeoLocation: base.GeoLocation{
				Latitude:  req.Latitude,
				Longitude: req.Longitude,
			},
		},
		Name:             req.Name,
		Description:      req.Description,
		Phone:            req.Phone,
		HoursOfOperation: req.HoursOfOperation,
		IsActive:         false, // Set to false - will be activated upon approval
	}

	// Create restaurant and vendor relationship in a transaction
	if err := h.App.Deps.Restaurants.CreateWithVendor(restaurant, vendorID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create restaurant", err)
		return
	}

	// Send response
	sendJSON(w, http.StatusCreated, map[string]interface{}{
		"success":    true,
		"message":    "Restaurant created successfully",
		"restaurant": restaurant,
	})
}

// GetRestaurants retrieves restaurants
// - Vendors see only their own restaurants
// - Admins see all restaurants
// - Customers and drivers see all active restaurants
func (h *Handler) GetRestaurants(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	restaurants := make([]models.Restaurant, 0)
	var err error

	switch user.UserType {
	case models.UserTypeVendor:
		// Get vendor ID using repository helper
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}
		restaurants, err = h.App.Deps.Restaurants.GetByVendorID(vendorID)
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
			return
		}

	case models.UserTypeAdmin:
		// Admins see all restaurants
		restaurants, err = h.App.Deps.Restaurants.GetAll()
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
			return
		}

	case models.UserTypeCustomer, models.UserTypeDriver:
		// Customers and drivers see only approved and active restaurants
		restaurants, err = h.App.Deps.Restaurants.GetApprovedRestaurants()
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
			return
		}

		// Filter by operating hours - only show restaurants that are currently open
		openRestaurants := make([]models.Restaurant, 0)
		for _, restaurant := range restaurants {
			isOpen, err := utils.IsRestaurantOpen(restaurant.HoursOfOperation, restaurant.Timezone)
			if err != nil {
				// Log the error but continue processing
				log.Printf("[Hours Filter] Error checking hours for restaurant %d (%s): %v",
					restaurant.ID, restaurant.Name, err)
				// If there's an error checking hours, include the restaurant to avoid hiding it
				openRestaurants = append(openRestaurants, restaurant)
				continue
			}

			if isOpen {
				openRestaurants = append(openRestaurants, restaurant)
			} else {
				// Log when restaurants are filtered out for debugging
				log.Printf("[Hours Filter] Restaurant %d (%s) is currently closed",
					restaurant.ID, restaurant.Name)
			}
		}

		restaurants = openRestaurants

	default:
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":     true,
		"restaurants": restaurants,
	})
}

// GetRestaurant retrieves a specific restaurant by ID
func (h *Handler) GetRestaurant(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL using helper
	restaurantID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Get restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check access permissions
	if user.UserType == models.UserTypeVendor {
		// Vendors can only view their own restaurants
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership using repository method
		if err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
			sendError(w, http.StatusForbidden, "You don't have permission to access this restaurant")
			return
		}
	} else if user.UserType == models.UserTypeCustomer || user.UserType == models.UserTypeDriver {
		// Customers and drivers can only view approved and active restaurants
		if !restaurant.IsActive || restaurant.ApprovalStatus != base.ApprovalStatusApproved {
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	}
	// Admins can view any restaurant

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"restaurant": restaurant,
	})
}

// UpdateRestaurant updates an existing restaurant
// Only the owning vendor or admin can update
func (h *Handler) UpdateRestaurant(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL using helper
	restaurantID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Get existing restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check ownership for vendors
	if user.UserType == models.UserTypeVendor {
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership using repository method
		if err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
			sendError(w, http.StatusForbidden, "You don't have permission to update this restaurant")
			return
		}
	} else if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Only vendors and admins can update restaurants")
		return
	}

	// Decode request
	var req models.UpdateRestaurantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Update fields if provided
	if req.Name != nil {
		restaurant.Name = *req.Name
	}
	if req.Description != nil {
		restaurant.Description = req.Description
	}
	if req.Phone != nil {
		restaurant.Phone = req.Phone
	}
	if req.AddressLine1 != nil {
		restaurant.AddressLine1 = req.AddressLine1
	}
	if req.AddressLine2 != nil {
		restaurant.AddressLine2 = req.AddressLine2
	}
	if req.City != nil {
		restaurant.City = req.City
	}
	if req.State != nil {
		restaurant.State = req.State
	}
	if req.PostalCode != nil {
		restaurant.PostalCode = req.PostalCode
	}
	if req.Country != nil {
		restaurant.Country = req.Country
	}
	if req.Latitude != nil {
		restaurant.Latitude = req.Latitude
	}
	if req.Longitude != nil {
		restaurant.Longitude = req.Longitude
	}
	if req.HoursOfOperation != nil {
		restaurant.HoursOfOperation = req.HoursOfOperation
	}
	if req.IsActive != nil {
		restaurant.IsActive = *req.IsActive
	}

	// Update restaurant
	if err := h.App.Deps.Restaurants.Update(restaurant); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update restaurant", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"message":    "Restaurant updated successfully",
		"restaurant": restaurant,
	})
}

// DeleteRestaurant deletes a restaurant
// Only the owning vendor or admin can delete
func (h *Handler) DeleteRestaurant(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL using helper
	restaurantID, err := h.GetIntParam(r, "id")
	if err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Check if restaurant exists
	_, err = h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check ownership for vendors
	if user.UserType == models.UserTypeVendor {
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership using repository method
		if err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
			sendError(w, http.StatusForbidden, "You don't have permission to delete this restaurant")
			return
		}
	} else if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Only vendors and admins can delete restaurants")
		return
	}

	// Delete restaurant (cascade will delete vendor_restaurants)
	if err := h.App.Deps.Restaurants.Delete(restaurantID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete restaurant", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Restaurant deleted successfully",
	})
}
