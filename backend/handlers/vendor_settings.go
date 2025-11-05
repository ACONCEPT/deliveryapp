package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
)

// GetRestaurantSettings retrieves restaurant settings for the authenticated vendor or admin
// GET /api/vendor/restaurant/{restaurantId}/settings
func (h *Handler) GetRestaurantSettings(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantIDStr := vars["restaurantId"]
	restaurantID, err := strconv.Atoi(restaurantIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Authorization check
	var restaurant *models.Restaurant
	if user.UserType == models.UserTypeAdmin {
		// Admin can access any restaurant
		restaurant, err = h.App.Deps.Restaurants.GetByID(restaurantID)
		if err != nil {
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else if user.UserType == models.UserTypeVendor {
		// Vendor can only access their own restaurants
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership and get restaurant
		restaurant, err = h.App.Deps.Restaurants.GetByIDWithOwnershipCheck(restaurantID, vendorID)
		if err != nil {
			if strings.Contains(err.Error(), "does not belong") {
				sendError(w, http.StatusForbidden, "You do not have permission to access this restaurant")
				return
			}
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else {
		sendError(w, http.StatusForbidden, "Only vendors and admins can access restaurant settings")
		return
	}

	// Parse hours of operation if present
	var hoursOfOperation *models.HoursOfOperation
	if restaurant.HoursOfOperation != nil && *restaurant.HoursOfOperation != "" {
		hoursOfOperation = &models.HoursOfOperation{}
		if err := json.Unmarshal([]byte(*restaurant.HoursOfOperation), hoursOfOperation); err != nil {
			// If parsing fails, return nil for hours
			hoursOfOperation = nil
		}
	}

	// Build response
	settings := models.VendorSettings{
		RestaurantID:       restaurant.ID,
		RestaurantName:     restaurant.Name,
		AveragePrepTimeMin: restaurant.AveragePrepTimeMin,
		HoursOfOperation:   hoursOfOperation,
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    settings,
	})
}

// UpdateRestaurantSettings updates restaurant settings (hours and/or prep time)
// PUT /api/vendor/restaurant/{restaurantId}/settings
func (h *Handler) UpdateRestaurantSettings(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantIDStr := vars["restaurantId"]
	restaurantID, err := strconv.Atoi(restaurantIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Authorization check
	if user.UserType == models.UserTypeAdmin {
		// Admin can modify any restaurant - verify it exists
		_, err := h.App.Deps.Restaurants.GetByID(restaurantID)
		if err != nil {
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else if user.UserType == models.UserTypeVendor {
		// Vendor can only modify their own restaurants
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership
		if err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
			if strings.Contains(err.Error(), "does not belong") {
				sendError(w, http.StatusForbidden, "You do not have permission to modify this restaurant")
				return
			}
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else {
		sendError(w, http.StatusForbidden, "Only vendors and admins can modify restaurant settings")
		return
	}

	// Decode request
	var req models.UpdateVendorSettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate at least one field is provided
	if req.AveragePrepTimeMin == nil && req.HoursOfOperation == nil {
		sendError(w, http.StatusBadRequest, "At least one field must be provided")
		return
	}

	// Validate prep time if provided
	if req.AveragePrepTimeMin != nil {
		if *req.AveragePrepTimeMin < 1 || *req.AveragePrepTimeMin > 300 {
			sendError(w, http.StatusBadRequest, "Average prep time must be between 1 and 300 minutes")
			return
		}
	}

	// Validate hours of operation if provided
	if req.HoursOfOperation != nil {
		if err := validateHoursOfOperation(req.HoursOfOperation); err != nil {
			sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid hours of operation: %s", err.Error()))
			return
		}
	}

	// Convert hours to JSON string if provided
	var hoursJSON *string
	if req.HoursOfOperation != nil {
		hoursBytes, err := json.Marshal(req.HoursOfOperation)
		if err != nil {
			sendError(w, http.StatusInternalServerError, "Failed to process hours of operation")
			return
		}
		hoursStr := string(hoursBytes)
		hoursJSON = &hoursStr
	}

	// Update restaurant settings
	if err := h.App.Deps.Restaurants.UpdateRestaurantSettings(restaurantID, hoursJSON, req.AveragePrepTimeMin); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update restaurant settings", err)
		return
	}

	// Get updated restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(restaurantID)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "Failed to retrieve updated restaurant")
		return
	}

	// Parse hours of operation
	var hoursOfOperation *models.HoursOfOperation
	if restaurant.HoursOfOperation != nil && *restaurant.HoursOfOperation != "" {
		hoursOfOperation = &models.HoursOfOperation{}
		if err := json.Unmarshal([]byte(*restaurant.HoursOfOperation), hoursOfOperation); err != nil {
			hoursOfOperation = nil
		}
	}

	// Build response
	settings := models.VendorSettings{
		RestaurantID:       restaurant.ID,
		RestaurantName:     restaurant.Name,
		AveragePrepTimeMin: restaurant.AveragePrepTimeMin,
		HoursOfOperation:   hoursOfOperation,
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Restaurant settings updated successfully",
		"data":    settings,
	})
}

// UpdateRestaurantPrepTime updates only the average prep time
// PATCH /api/vendor/restaurant/{restaurantId}/prep-time
func (h *Handler) UpdateRestaurantPrepTime(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get restaurant ID from URL
	vars := mux.Vars(r)
	restaurantIDStr := vars["restaurantId"]
	restaurantID, err := strconv.Atoi(restaurantIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid restaurant ID")
		return
	}

	// Authorization check
	if user.UserType == models.UserTypeAdmin {
		// Admin can modify any restaurant - verify it exists
		_, err := h.App.Deps.Restaurants.GetByID(restaurantID)
		if err != nil {
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else if user.UserType == models.UserTypeVendor {
		// Vendor can only modify their own restaurants
		vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
		if err != nil {
			sendError(w, http.StatusForbidden, "Vendor profile not found")
			return
		}

		// Verify ownership
		if err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID); err != nil {
			if strings.Contains(err.Error(), "does not belong") {
				sendError(w, http.StatusForbidden, "You do not have permission to modify this restaurant")
				return
			}
			sendError(w, http.StatusNotFound, "Restaurant not found")
			return
		}
	} else {
		sendError(w, http.StatusForbidden, "Only vendors and admins can modify restaurant settings")
		return
	}

	// Decode request
	var req models.UpdatePrepTimeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate prep time
	if req.AveragePrepTimeMin < 1 || req.AveragePrepTimeMin > 300 {
		sendError(w, http.StatusBadRequest, "Average prep time must be between 1 and 300 minutes")
		return
	}

	// Update prep time
	if err := h.App.Deps.Restaurants.UpdateRestaurantPrepTime(restaurantID, req.AveragePrepTimeMin); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update prep time", err)
		return
	}

	sendJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Average prep time updated successfully",
		"data": map[string]interface{}{
			"restaurant_id":             restaurantID,
			"average_prep_time_minutes": req.AveragePrepTimeMin,
		},
	})
}

// validateHoursOfOperation validates the hours of operation structure
func validateHoursOfOperation(hours *models.HoursOfOperation) error {
	if hours == nil {
		return fmt.Errorf("hours of operation cannot be nil")
	}

	days := []struct {
		name     string
		schedule models.DaySchedule
	}{
		{"Monday", hours.Monday},
		{"Tuesday", hours.Tuesday},
		{"Wednesday", hours.Wednesday},
		{"Thursday", hours.Thursday},
		{"Friday", hours.Friday},
		{"Saturday", hours.Saturday},
		{"Sunday", hours.Sunday},
	}

	for _, day := range days {
		if !day.schedule.Closed {
			// Validate time format (HH:MM)
			if err := validateTimeFormat(day.schedule.Open); err != nil {
				return fmt.Errorf("%s open time: %w", day.name, err)
			}
			if err := validateTimeFormat(day.schedule.Close); err != nil {
				return fmt.Errorf("%s close time: %w", day.name, err)
			}

			// Validate open < close
			openTime, _ := time.Parse("15:04", day.schedule.Open)
			closeTime, _ := time.Parse("15:04", day.schedule.Close)
			if !openTime.Before(closeTime) {
				return fmt.Errorf("%s: open time must be before close time", day.name)
			}
		}
	}

	return nil
}

// validateTimeFormat validates time is in HH:MM format
func validateTimeFormat(timeStr string) error {
	_, err := time.Parse("15:04", timeStr)
	if err != nil {
		return fmt.Errorf("invalid time format, must be HH:MM (24-hour)")
	}
	return nil
}
