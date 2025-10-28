package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

// ============================================================================
// SYSTEM SETTINGS HANDLERS (Admin-only)
// ============================================================================

// GetSystemSettings retrieves all system settings, optionally grouped by category
func (h *Handler) GetSystemSettings(w http.ResponseWriter, r *http.Request) {
	// Get query parameter for filtering
	category := r.URL.Query().Get("category")

	settings := make([]models.SystemSetting, 0)
	var err error

	if category != "" {
		// Get settings for specific category
		settings, err = h.App.Deps.Config.GetSettingsByCategory(category)
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve settings", err)
			return
		}
	} else {
		// Get all settings
		settings, err = h.App.Deps.Config.GetAllSettings()
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve settings", err)
			return
		}
	}

	// Group settings by category
	settingsByCategory := make(models.SettingsByCategory)
	for _, setting := range settings {
		cat := setting.Category
		if cat == "" {
			cat = "uncategorized"
		}
		settingsByCategory[cat] = append(settingsByCategory[cat], setting)
	}

	// Build response
	response := models.SettingsResponse{
		Settings:        settingsByCategory,
		TotalCount:      len(settings),
		CategoriesCount: len(settingsByCategory),
	}

	sendSuccess(w, http.StatusOK, "Settings retrieved successfully", response)
}

// GetSettingByKey retrieves a single setting by its key
func (h *Handler) GetSettingByKey(w http.ResponseWriter, r *http.Request) {
	// Get key from URL path
	vars := mux.Vars(r)
	key := vars["key"]

	if key == "" {
		sendError(w, http.StatusBadRequest, "Setting key is required")
		return
	}

	// Retrieve setting
	setting, err := h.App.Deps.Config.GetSettingByKey(key)
	if err != nil {
		sendError(w, http.StatusNotFound, err.Error())
		return
	}

	sendSuccess(w, http.StatusOK, "Setting retrieved successfully", setting)
}

// UpdateSetting updates a single setting value (admin only)
func (h *Handler) UpdateSetting(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Only admins can update settings (enforced by middleware, but double-check)
	if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Only admins can update system settings")
		return
	}

	// Get key from URL path
	vars := mux.Vars(r)
	key := vars["key"]

	if key == "" {
		sendError(w, http.StatusBadRequest, "Setting key is required")
		return
	}

	// Decode request
	var req models.UpdateSettingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Value == "" {
		sendError(w, http.StatusBadRequest, "Setting value is required")
		return
	}

	// Update setting
	if err := h.App.Deps.Config.UpdateSetting(key, req.Value); err != nil {
		// Check if it's a validation error or permission error
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Retrieve updated setting
	updatedSetting, err := h.App.Deps.Config.GetSettingByKey(key)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Setting updated but failed to retrieve", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Setting updated successfully", updatedSetting)
}

// UpdateMultipleSettings updates multiple settings in a single transaction (admin only)
func (h *Handler) UpdateMultipleSettings(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Only admins can update settings (enforced by middleware, but double-check)
	if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Only admins can update system settings")
		return
	}

	// Decode request
	var req models.UpdateMultipleSettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if len(req.Settings) == 0 {
		sendError(w, http.StatusBadRequest, "At least one setting must be provided")
		return
	}

	// Convert to map for repository
	updates := make(map[string]string)
	updatedKeys := make([]string, 0, len(req.Settings))

	for _, setting := range req.Settings {
		if setting.Key == "" {
			sendError(w, http.StatusBadRequest, "Setting key cannot be empty")
			return
		}
		updates[setting.Key] = setting.Value
		updatedKeys = append(updatedKeys, setting.Key)
	}

	// Update settings (atomic transaction)
	if err := h.App.Deps.Config.UpdateMultipleSettings(updates); err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Build success result
	result := models.BatchUpdateResult{
		SuccessCount: len(updatedKeys),
		FailureCount: 0,
		UpdatedKeys:  updatedKeys,
		Errors:       []models.SettingValidationError{},
	}

	sendSuccess(w, http.StatusOK, "Settings updated successfully", result)
}

// GetCategories retrieves all unique setting categories
func (h *Handler) GetCategories(w http.ResponseWriter, r *http.Request) {
	categories, err := h.App.Deps.Config.GetCategories()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve categories", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Categories retrieved successfully", map[string]interface{}{
		"categories": categories,
		"count":      len(categories),
	})
}
