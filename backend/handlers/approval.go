package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"delivery_app/backend/models/base"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// GetPendingVendors returns all vendors awaiting approval (admin only)
func (h *Handler) GetPendingVendors(w http.ResponseWriter, r *http.Request) {
	vendors, err := h.App.Deps.Users.GetPendingVendors()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve pending vendors", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Pending vendors retrieved successfully", vendors)
}

// GetPendingRestaurants returns all restaurants awaiting approval (admin only)
func (h *Handler) GetPendingRestaurants(w http.ResponseWriter, r *http.Request) {
	restaurants, err := h.App.Deps.Restaurants.GetPendingRestaurants()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve pending restaurants", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Pending restaurants retrieved successfully", restaurants)
}

// GetApprovalDashboard returns summary counts for admin dashboard
func (h *Handler) GetApprovalDashboard(w http.ResponseWriter, r *http.Request) {
	stats, err := h.App.Deps.Approvals.GetApprovalStats()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve approval statistics", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Approval statistics retrieved successfully", stats)
}

// ApproveVendor approves a vendor (admin only)
func (h *Handler) ApproveVendor(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get vendor ID from URL
	vars := mux.Vars(r)
	vendorIDStr := vars["id"]
	vendorID, err := strconv.Atoi(vendorIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid vendor ID")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify vendor exists
	vendor, err := h.App.Deps.Users.GetVendorByID(vendorID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor not found")
		return
	}

	// Check if already approved
	if vendor.ApprovalStatus == base.ApprovalStatusApproved {
		sendError(w, http.StatusBadRequest, "Vendor is already approved")
		return
	}

	// Approve vendor
	err = h.App.Deps.Users.ApproveVendor(vendorID, adminProfile.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to approve vendor", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "vendor",
		EntityID:   vendorID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusApproved,
		Reason:     nil,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Vendor approved successfully", nil)
}

// RejectVendor rejects a vendor with a reason (admin only)
func (h *Handler) RejectVendor(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get vendor ID from URL
	vars := mux.Vars(r)
	vendorIDStr := vars["id"]
	vendorID, err := strconv.Atoi(vendorIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid vendor ID")
		return
	}

	// Decode request body
	var req models.ApprovalActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate rejection reason is provided
	if req.Reason == nil || *req.Reason == "" {
		sendError(w, http.StatusBadRequest, "Rejection reason is required")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify vendor exists
	vendor, err := h.App.Deps.Users.GetVendorByID(vendorID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor not found")
		return
	}

	// Check if already rejected
	if vendor.ApprovalStatus == base.ApprovalStatusRejected {
		sendError(w, http.StatusBadRequest, "Vendor is already rejected")
		return
	}

	// Reject vendor
	err = h.App.Deps.Users.RejectVendor(vendorID, adminProfile.ID, *req.Reason)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to reject vendor", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "vendor",
		EntityID:   vendorID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusRejected,
		Reason:     req.Reason,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Vendor rejected successfully", nil)
}

// ApproveRestaurant approves a restaurant (admin only)
func (h *Handler) ApproveRestaurant(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantIDStr := vars["id"]
	restaurantID, err := strconv.Atoi(restaurantIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify restaurant exists
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check if already approved
	if restaurant.ApprovalStatus == base.ApprovalStatusApproved {
		sendError(w, http.StatusBadRequest, "Restaurant is already approved")
		return
	}

	// Approve restaurant
	err = h.App.Deps.Restaurants.ApproveRestaurant(restaurantID, adminProfile.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to approve restaurant", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "restaurant",
		EntityID:   restaurantID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusApproved,
		Reason:     nil,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Restaurant approved successfully", nil)
}

// RejectRestaurant rejects a restaurant with a reason (admin only)
func (h *Handler) RejectRestaurant(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantIDStr := vars["id"]
	restaurantID, err := strconv.Atoi(restaurantIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Decode request body
	var req models.ApprovalActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate rejection reason is provided
	if req.Reason == nil || *req.Reason == "" {
		sendError(w, http.StatusBadRequest, "Rejection reason is required")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify restaurant exists
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check if already rejected
	if restaurant.ApprovalStatus == base.ApprovalStatusRejected {
		sendError(w, http.StatusBadRequest, "Restaurant is already rejected")
		return
	}

	// Reject restaurant
	err = h.App.Deps.Restaurants.RejectRestaurant(restaurantID, adminProfile.ID, *req.Reason)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to reject restaurant", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "restaurant",
		EntityID:   restaurantID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusRejected,
		Reason:     req.Reason,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Restaurant rejected successfully", nil)
}

// GetApprovalHistory returns approval/rejection history for an entity (admin only)
func (h *Handler) GetApprovalHistory(w http.ResponseWriter, r *http.Request) {
	// Get query parameters
	entityType := r.URL.Query().Get("entity_type")
	entityIDStr := r.URL.Query().Get("entity_id")

	if entityType == "" || entityIDStr == "" {
		sendError(w, http.StatusBadRequest, "entity_type and entity_id are required")
		return
	}

	entityID, err := strconv.Atoi(entityIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid entity_id")
		return
	}

	// Validate entity type
	if entityType != "vendor" && entityType != "restaurant" && entityType != "driver" {
		sendError(w, http.StatusBadRequest, "entity_type must be 'vendor', 'restaurant', or 'driver'")
		return
	}

	// Get approval history
	history, err := h.App.Deps.Approvals.GetEntityApprovalHistory(entityType, entityID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve approval history", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Approval history retrieved successfully", history)
}

// GetVendorApprovalStatus returns the approval status for the authenticated vendor
func (h *Handler) GetVendorApprovalStatus(w http.ResponseWriter, r *http.Request) {
	// Get vendor from context
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Create response
	response := models.VendorApprovalStatusResponse{
		VendorID:             vendor.ID,
		ApprovalStatus:       base.ApprovalStatus(vendor.ApprovalStatus),
		RejectionReason:      vendor.RejectionReason,
		ApprovedAt:           vendor.ApprovedAt,
		CanCreateRestaurants: vendor.ApprovalStatus == base.ApprovalStatusApproved ,
	}

	sendSuccess(w, http.StatusOK, "Vendor approval status retrieved successfully", response)
}

// GetPendingDrivers returns all drivers awaiting approval (admin only)
func (h *Handler) GetPendingDrivers(w http.ResponseWriter, r *http.Request) {
	drivers, err := h.App.Deps.Users.GetPendingDrivers()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve pending drivers", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Pending drivers retrieved successfully", drivers)
}

// ApproveDriver approves a driver (admin only)
func (h *Handler) ApproveDriver(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get driver ID from URL
	vars := mux.Vars(r)
	driverIDStr := vars["id"]
	driverID, err := strconv.Atoi(driverIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid driver ID")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify driver exists
	driver, err := h.App.Deps.Users.GetDriverByID(driverID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver not found")
		return
	}

	// Check if already approved
	if driver.ApprovalStatus == base.ApprovalStatusApproved {
		sendError(w, http.StatusBadRequest, "Driver is already approved")
		return
	}

	// Approve driver
	err = h.App.Deps.Users.ApproveDriver(driverID, adminProfile.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to approve driver", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "driver",
		EntityID:   driverID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusApproved,
		Reason:     nil,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Driver approved successfully", nil)
}

// RejectDriver rejects a driver with a reason (admin only)
func (h *Handler) RejectDriver(w http.ResponseWriter, r *http.Request) {
	// Get admin from context
	admin := middleware.MustGetUserFromContext(r.Context())

	// Get driver ID from URL
	vars := mux.Vars(r)
	driverIDStr := vars["id"]
	driverID, err := strconv.Atoi(driverIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid driver ID")
		return
	}

	// Decode request body
	var req models.ApprovalActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate rejection reason is provided
	if req.Reason == nil || *req.Reason == "" {
		sendError(w, http.StatusBadRequest, "Rejection reason is required")
		return
	}

	// Get admin profile to get admin ID
	adminProfile, err := h.App.Deps.Users.GetAdminByUserID(admin.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve admin profile", err)
		return
	}

	// Verify driver exists
	driver, err := h.App.Deps.Users.GetDriverByID(driverID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver not found")
		return
	}

	// Check if already rejected
	if driver.ApprovalStatus == base.ApprovalStatusRejected {
		sendError(w, http.StatusBadRequest, "Driver is already rejected")
		return
	}

	// Reject driver
	err = h.App.Deps.Users.RejectDriver(driverID, adminProfile.ID, *req.Reason)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to reject driver", err)
		return
	}

	// Create approval history entry
	history := &models.ApprovalHistory{
		EntityType: "driver",
		EntityID:   driverID,
		AdminID:    adminProfile.ID,
		Action:     base.ApprovalStatusRejected,
		Reason:     req.Reason,
	}
	err = h.App.Deps.Approvals.CreateApprovalHistory(history)
	if err != nil {
		// Log error but don't fail the request
		// TODO: Add proper logging
	}

	sendSuccess(w, http.StatusOK, "Driver rejected successfully", nil)
}

// GetDriverApprovalStatus returns the approval status for the authenticated driver
func (h *Handler) GetDriverApprovalStatus(w http.ResponseWriter, r *http.Request) {
	// Get driver from context
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
		return
	}

	// Create response
	response := models.DriverApprovalStatusResponse{
		DriverID:        driver.ID,
		ApprovalStatus:  driver.ApprovalStatus,
		RejectionReason: driver.RejectionReason,
		ApprovedAt:      driver.ApprovedAt,
		CanAcceptOrders: driver.ApprovalStatus == base.ApprovalStatusApproved ,
	}

	sendSuccess(w, http.StatusOK, "Driver approval status retrieved successfully", response)
}