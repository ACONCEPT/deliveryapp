package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// GetVendorRestaurants retrieves all vendor-restaurant relationships
// Only admins can access this endpoint
func (h *Handler) GetVendorRestaurants(w http.ResponseWriter, r *http.Request) {
	vendorRestaurants, err := h.App.Deps.VendorRestaurants.GetAll()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve vendor-restaurant relationships", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":            true,
		"vendor_restaurants": vendorRestaurants,
	})
}

// GetVendorRestaurant retrieves a specific vendor-restaurant relationship
// Admins can access any relationship, vendors can access their own
func (h *Handler) GetVendorRestaurant(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor-restaurant ID from URL
	vars := mux.Vars(r)
	vrID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid vendor-restaurant ID")
		return
	}

	// Get vendor-restaurant relationship
	vendorRestaurant, err := h.App.Deps.VendorRestaurants.GetByID(vrID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor-restaurant relationship not found")
		return
	}

	// Check permissions for vendors
	if user.UserType == models.UserTypeVendor {
		vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		if vendorRestaurant.VendorID != vendor.ID {
			sendError(w, http.StatusForbidden, "You don't have permission to access this relationship")
			return
		}
	} else if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Only vendors and admins can access this endpoint")
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":           true,
		"vendor_restaurant": vendorRestaurant,
	})
}

// GetRestaurantOwner retrieves the vendor who owns a specific restaurant
func (h *Handler) GetRestaurantOwner(w http.ResponseWriter, r *http.Request) {
	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Get vendor-restaurant relationship
	vendorRestaurant, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "No vendor found for this restaurant")
		return
	}

	// Get vendor details
	vendor, err := h.App.Deps.Users.GetVendorByUserID(vendorRestaurant.VendorID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve vendor information", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success":           true,
		"vendor_restaurant": vendorRestaurant,
		"vendor":            vendor,
	})
}

// TransferRestaurantOwnership transfers a restaurant to a new vendor
// Only admins can perform this operation
func (h *Handler) TransferRestaurantOwnership(w http.ResponseWriter, r *http.Request) {
	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Decode request
	var req struct {
		NewVendorID int `json:"new_vendor_id" validate:"required"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.NewVendorID <= 0 {
		sendError(w, http.StatusBadRequest, "Invalid vendor ID")
		return
	}

	// Verify restaurant exists
	_, err = h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Verify new vendor exists
	_, err = h.App.Deps.Users.GetVendorByUserID(req.NewVendorID)
	if err != nil {
		sendError(w, http.StatusBadRequest, "New vendor not found")
		return
	}

	// Transfer ownership
	if err := h.App.Deps.VendorRestaurants.TransferOwnership(restaurantID, req.NewVendorID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to transfer ownership", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Restaurant ownership transferred successfully",
	})
}

// DeleteVendorRestaurant removes a vendor-restaurant relationship
// Only admins can perform this operation
// WARNING: This orphans the restaurant (no vendor owns it)
func (h *Handler) DeleteVendorRestaurant(w http.ResponseWriter, r *http.Request) {
	// Get vendor-restaurant ID from URL
	vars := mux.Vars(r)
	vrID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid vendor-restaurant ID")
		return
	}

	// Verify relationship exists
	_, err = h.App.Deps.VendorRestaurants.GetByID(vrID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor-restaurant relationship not found")
		return
	}

	// Delete relationship
	if err := h.App.Deps.VendorRestaurants.Delete(vrID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete relationship", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Vendor-restaurant relationship deleted successfully",
	})
}
