package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// DeleteUser deletes a user by ID (admin only)
// Prevents deletion of:
// - The requesting admin themselves
// - The last admin in the system
func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	// Get authenticated admin user
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract user ID from URL
	vars := mux.Vars(r)
	userIDStr := vars["id"]
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid user ID")
		return
	}

	// Prevent admin from deleting themselves
	if authUser.UserID == userID {
		sendError(w, http.StatusBadRequest, "Cannot delete your own account")
		return
	}

	// Fetch the target user to verify existence and get user type
	targetUser, err := h.App.Deps.Users.GetByID(userID)
	if err != nil {
		sendError(w, http.StatusNotFound, "User not found")
		return
	}

	// If deleting an admin, check if they're the last admin
	if targetUser.UserType == models.UserTypeAdmin {
		adminCount, err := h.App.Deps.Users.CountAdminUsers()
		if err != nil {
			log.Printf("Error counting admin users: %v", err)
			sendError(w, http.StatusInternalServerError, "Failed to verify admin count")
			return
		}

		if adminCount <= 1 {
			sendError(w, http.StatusBadRequest, "Cannot delete the last admin user")
			return
		}
	}

	// Delete the user (cascade deletes associated profile data)
	err = h.App.Deps.Users.DeleteUser(userID)
	if err != nil {
		log.Printf("Error deleting user ID %d: %v", userID, err)
		sendError(w, http.StatusInternalServerError, "Failed to delete user")
		return
	}

	// Log the deletion action for audit trail
	log.Printf("User deleted - ID: %d, Type: %s, Username: %s (deleted by admin: %s)",
		userID, targetUser.UserType, targetUser.Username, authUser.Username)

	sendSuccess(w, http.StatusOK, fmt.Sprintf("User '%s' deleted successfully", targetUser.Username), nil)
}

// GetAllUsers lists all users with filtering, searching, and pagination (admin only)
func (h *Handler) GetAllUsers(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	userType := r.URL.Query().Get("user_type")
	status := r.URL.Query().Get("status")
	search := r.URL.Query().Get("search")

	// Validate user_type if provided
	if userType != "" {
		validTypes := map[string]bool{
			string(models.UserTypeCustomer): true,
			string(models.UserTypeVendor):   true,
			string(models.UserTypeDriver):   true,
			string(models.UserTypeAdmin):    true,
		}
		if !validTypes[userType] {
			sendError(w, http.StatusBadRequest, "Invalid user_type. Must be one of: customer, vendor, driver, admin")
			return
		}
	}

	// Validate status if provided
	if status != "" {
		validStatuses := map[string]bool{
			string(models.UserStatusActive):    true,
			string(models.UserStatusInactive):  true,
			string(models.UserStatusSuspended): true,
			"pending":                          true, // For drivers/vendors
			"approved":                         true,
			"rejected":                         true,
		}
		if !validStatuses[status] {
			sendError(w, http.StatusBadRequest, "Invalid status")
			return
		}
	}

	// Parse pagination parameters
	page := 1
	if pageStr := r.URL.Query().Get("page"); pageStr != "" {
		var err error
		page, err = strconv.Atoi(pageStr)
		if err != nil || page < 1 {
			sendError(w, http.StatusBadRequest, "Invalid page number")
			return
		}
	}

	perPage := 20
	if perPageStr := r.URL.Query().Get("per_page"); perPageStr != "" {
		var err error
		perPage, err = strconv.Atoi(perPageStr)
		if err != nil || perPage < 1 || perPage > 100 {
			sendError(w, http.StatusBadRequest, "Invalid per_page value (must be 1-100)")
			return
		}
	}

	// Calculate offset
	offset := (page - 1) * perPage

	// Fetch users from repository
	users, totalCount, err := h.App.Deps.Users.GetAllUsers(userType, status, search, perPage, offset)
	if err != nil {
		log.Printf("Error fetching users: %v", err)
		sendError(w, http.StatusInternalServerError, "Failed to retrieve users")
		return
	}

	// Calculate total pages
	totalPages := (totalCount + perPage - 1) / perPage
	if totalPages < 1 {
		totalPages = 1
	}

	// Build response
	response := models.GetAllUsersResponse{
		Users:      users,
		TotalCount: totalCount,
		Page:       page,
		PerPage:    perPage,
		TotalPages: totalPages,
	}

	sendSuccess(w, http.StatusOK, "Users retrieved successfully", response)
}
