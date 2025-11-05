package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// CreateMenu handles POST /api/vendor/menus
func (h *Handler) CreateMenu(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Decode request
	var req models.CreateMenuRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate name is not empty
	if strings.TrimSpace(req.Name) == "" {
		sendError(w, http.StatusBadRequest, "Menu name is required")
		return
	}

	// Validate menu_config is valid JSON
	var configTest map[string]interface{}
	if err := json.Unmarshal([]byte(req.MenuConfig), &configTest); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu_config JSON")
		return
	}

	// Validate menu_config size (max 500KB)
	const maxMenuSize = 500 * 1024 // 500KB
	if len(req.MenuConfig) > maxMenuSize {
		sendError(w, http.StatusBadRequest,
			"Menu too large: "+strconv.Itoa(len(req.MenuConfig)/1024)+"KB (max 500KB)")
		return
	}

	// Create menu with vendor ownership
	description := req.Description
	menu := &models.Menu{
		Name:        req.Name,
		Description: &description,
		MenuConfig:  req.MenuConfig,
		VendorID:    &vendor.ID,
		IsActive:    req.IsActive,
	}

	if err := h.App.Deps.Menus.Create(menu); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create menu", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Menu created successfully",
		"menu":    menu,
	}
	sendJSON(w, http.StatusCreated, response)
}

// GetVendorMenus handles GET /api/vendor/menus
func (h *Handler) GetVendorMenus(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Get menus for vendor
	menus, err := h.App.Deps.Menus.GetByVendorID(vendor.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to fetch menus", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"menus":   menus,
	}
	sendJSON(w, http.StatusOK, response)
}

// GetMenu handles GET /api/vendor/menus/{id}
func (h *Handler) GetMenu(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract menu ID
	vars := mux.Vars(r)
	menuID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify ownership
	owns, err := h.App.Deps.Menus.DoesVendorOwnMenu(vendor.ID, menuID)
	if err != nil || !owns {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Fetch menu
	menu, err := h.App.Deps.Menus.GetByID(menuID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Menu not found")
		return
	}

	response := map[string]interface{}{
		"success": true,
		"menu":    menu,
	}
	sendJSON(w, http.StatusOK, response)
}

// UpdateMenu handles PUT /api/vendor/menus/{id}
func (h *Handler) UpdateMenu(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract menu ID
	vars := mux.Vars(r)
	menuID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify ownership
	owns, err := h.App.Deps.Menus.DoesVendorOwnMenu(vendor.ID, menuID)
	if err != nil || !owns {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Fetch existing menu
	menu, err := h.App.Deps.Menus.GetByID(menuID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Menu not found")
		return
	}

	// Decode update request
	var req models.UpdateMenuRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Apply partial updates
	if req.Name != nil {
		if strings.TrimSpace(*req.Name) == "" {
			sendError(w, http.StatusBadRequest, "Menu name cannot be empty")
			return
		}
		menu.Name = *req.Name
	}
	if req.Description != nil {
		menu.Description = req.Description
	}
	if req.MenuConfig != nil {
		// Validate JSON
		var configTest map[string]interface{}
		if err := json.Unmarshal([]byte(*req.MenuConfig), &configTest); err != nil {
			sendError(w, http.StatusBadRequest, "Invalid menu_config JSON")
			return
		}

		// Validate menu_config size (max 500KB)
		const maxMenuSize = 500 * 1024 // 500KB
		if len(*req.MenuConfig) > maxMenuSize {
			sendError(w, http.StatusBadRequest,
				"Menu too large: "+strconv.Itoa(len(*req.MenuConfig)/1024)+"KB (max 500KB)")
			return
		}

		menu.MenuConfig = *req.MenuConfig
	}
	if req.IsActive != nil {
		menu.IsActive = *req.IsActive
	}

	// Update in database
	if err := h.App.Deps.Menus.Update(menu); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update menu", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Menu updated successfully",
		"menu":    menu,
	}
	sendJSON(w, http.StatusOK, response)
}

// DeleteMenu handles DELETE /api/vendor/menus/{id}
func (h *Handler) DeleteMenu(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract menu ID
	vars := mux.Vars(r)
	menuID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify ownership
	owns, err := h.App.Deps.Menus.DoesVendorOwnMenu(vendor.ID, menuID)
	if err != nil || !owns {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Delete menu (database CASCADE will automatically remove restaurant_menus assignments)
	if err := h.App.Deps.Menus.Delete(menuID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete menu", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Menu deleted successfully", nil)
}

// AssignMenuToRestaurant handles POST /api/vendor/restaurants/{restaurant_id}/menus/{menu_id}
func (h *Handler) AssignMenuToRestaurant(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract IDs
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}
	menuID, err := strconv.Atoi(vars["menu_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify vendor owns restaurant
	relationship, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurantID)
	if err != nil || relationship.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "Access denied: you don't own this restaurant")
		return
	}

	// Verify menu exists
	_, err = h.App.Deps.Menus.GetByID(menuID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Menu not found")
		return
	}

	// CRITICAL: Verify vendor owns the menu
	ownsMenu, err := h.App.Deps.Menus.DoesVendorOwnMenu(vendor.ID, menuID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to verify menu ownership", err)
		return
	}
	if !ownsMenu {
		sendError(w, http.StatusForbidden, "Access denied: you don't own this menu")
		return
	}

	// Decode request
	var req models.AssignMenuRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Create assignment
	assignment := &models.RestaurantMenu{
		RestaurantID: restaurantID,
		MenuID:       menuID,
		IsActive:     req.IsActive,
		DisplayOrder: req.DisplayOrder,
	}

	if err := h.App.Deps.Menus.AssignToRestaurant(assignment); err != nil {
		// Check for unique constraint violation
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
			sendError(w, http.StatusConflict, "Menu already assigned to restaurant")
			return
		}
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to assign menu", err)
		return
	}

	response := map[string]interface{}{
		"success":         true,
		"message":         "Menu assigned to restaurant successfully",
		"restaurant_menu": assignment,
	}
	sendJSON(w, http.StatusCreated, response)
}

// UnassignMenuFromRestaurant handles DELETE /api/vendor/restaurants/{restaurant_id}/menus/{menu_id}
func (h *Handler) UnassignMenuFromRestaurant(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract IDs
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}
	menuID, err := strconv.Atoi(vars["menu_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid menu ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify vendor owns restaurant
	relationship, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurantID)
	if err != nil || relationship.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "Access denied: you don't own this restaurant")
		return
	}

	// Verify vendor owns the menu (same ownership check as assign)
	ownsMenu, err := h.App.Deps.Menus.DoesVendorOwnMenu(vendor.ID, menuID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to verify menu ownership", err)
		return
	}
	if !ownsMenu {
		sendError(w, http.StatusForbidden, "Access denied: you don't own this menu")
		return
	}

	// Unassign menu
	if err := h.App.Deps.Menus.UnassignFromRestaurant(restaurantID, menuID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to unassign menu", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Menu unassigned from restaurant successfully", nil)
}

// SetActiveMenu handles PUT /api/vendor/restaurants/{restaurant_id}/active-menu
func (h *Handler) SetActiveMenu(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Extract restaurant ID
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify vendor owns restaurant
	relationship, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurantID)
	if err != nil || relationship.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Decode request
	var req models.SetActiveMenuRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Set active menu
	if err := h.App.Deps.Menus.SetActiveMenu(restaurantID, req.MenuID); err != nil {
		if strings.Contains(err.Error(), "not assigned to restaurant") {
			sendError(w, http.StatusBadRequest, err.Error())
			return
		}
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to set active menu", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Active menu updated successfully", nil)
}

// GetRestaurantMenu handles GET /api/restaurants/{restaurant_id}/menu
func (h *Handler) GetRestaurantMenu(w http.ResponseWriter, r *http.Request) {
	// Extract restaurant ID
	vars := mux.Vars(r)
	restaurantID, err := strconv.Atoi(vars["restaurant_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Get restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Get active menu
	menu, err := h.App.Deps.Menus.GetActiveMenuByRestaurantID(restaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "No active menu found for this restaurant")
		return
	}

	response := map[string]interface{}{
		"success": true,
		"restaurant": map[string]interface{}{
			"id":          restaurant.ID,
			"name":        restaurant.Name,
			"description": restaurant.Description,
		},
		"menu": menu,
	}
	sendJSON(w, http.StatusOK, response)
}

// GetAllMenus handles GET /api/admin/menus (admin only)
func (h *Handler) GetAllMenus(w http.ResponseWriter, r *http.Request) {
	// Get all menus
	menus, err := h.App.Deps.Menus.GetAll()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to fetch menus", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"menus":   menus,
	}
	sendJSON(w, http.StatusOK, response)
}
