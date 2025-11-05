package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"delivery_app/backend/services"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// DistanceHandler holds dependencies for distance calculation
type DistanceHandler struct {
	*Handler
	mapboxService *services.MapboxService
}

// NewDistanceHandler creates a new distance handler with Mapbox service
func NewDistanceHandler(h *Handler, mapboxToken string) *DistanceHandler {
	return &DistanceHandler{
		Handler:       h,
		mapboxService: services.NewMapboxService(mapboxToken),
	}
}

// EstimateDistance calculates driving distance between customer address and restaurant
// POST /api/distance/estimate
func (h *DistanceHandler) EstimateDistance(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	user := middleware.MustGetUserFromContext(r.Context())

	// Parse request body
	var req models.DistanceEstimateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate request
	if req.AddressID <= 0 {
		sendError(w, http.StatusBadRequest, "Invalid address_id: must be greater than 0")
		return
	}
	if req.RestaurantID <= 0 {
		sendError(w, http.StatusBadRequest, "Invalid restaurant_id: must be greater than 0")
		return
	}

	// Fetch customer address
	address, err := h.App.Deps.Addresses.GetByID(req.AddressID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Address not found")
		return
	}

	// Verify address ownership (customers can only calculate distance for their own addresses)
	if user.UserType == models.UserTypeCustomer {
		customer, err := h.App.Deps.Users.GetCustomerByUserID(user.UserID)
		if err != nil {
			sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to verify customer", err)
			return
		}
		if address.CustomerID != customer.ID {
			sendError(w, http.StatusForbidden, "You don't have permission to access this address")
			return
		}
	}

	// Fetch restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(req.RestaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Validate coordinates
	if address.Latitude == nil || address.Longitude == nil {
		sendError(w, http.StatusBadRequest, "Address does not have valid coordinates")
		return
	}
	if restaurant.Latitude == nil || restaurant.Longitude == nil {
		sendError(w, http.StatusBadRequest, "Restaurant does not have valid coordinates")
		return
	}

	// Call Mapbox API to calculate distance
	result, err := h.mapboxService.GetDrivingDistance(
		*address.Longitude, *address.Latitude,
		*restaurant.Longitude, *restaurant.Latitude,
	)

	// Determine request status
	var status models.DistanceRequestStatus
	var errorMessage *string
	var distanceMeters *int
	var durationSeconds *int

	if err != nil {
		// Network/connection error
		status = models.DistanceRequestStatusError
		errMsg := err.Error()
		errorMessage = &errMsg
		log.Printf("[ERROR] Mapbox API call failed: %v", err)
	} else if result.Error != nil {
		// API returned an error
		errMsg := result.Error.Error()
		errorMessage = &errMsg

		if result.StatusCode == http.StatusTooManyRequests {
			status = models.DistanceRequestStatusRateLimited
		} else if result.StatusCode == http.StatusUnprocessableEntity || result.StatusCode == http.StatusNotFound {
			status = models.DistanceRequestStatusInvalidCoordinates
		} else {
			status = models.DistanceRequestStatusError
		}
	} else {
		// Success
		status = models.DistanceRequestStatusSuccess
		distanceMeters = &result.DistanceMeters
		durationSeconds = &result.DurationSeconds
	}

	// Log request to database
	distanceReq := &models.DistanceRequest{
		UserID:                  user.UserID,
		OriginAddressID:         &req.AddressID,
		DestinationRestaurantID: &req.RestaurantID,
		OriginLatitude:          address.Latitude,
		OriginLongitude:         address.Longitude,
		DestinationLatitude:     restaurant.Latitude,
		DestinationLongitude:    restaurant.Longitude,
		Status:                  status,
		DistanceMeters:          distanceMeters,
		DurationSeconds:         durationSeconds,
		APIResponseTimeMs:       &result.ResponseTimeMs,
		ErrorMessage:            errorMessage,
		MapboxRequestID:         &result.RequestID,
	}

	if err := h.App.Deps.Distance.CreateDistanceRequest(distanceReq); err != nil {
		log.Printf("[ERROR] Failed to log distance request: %v", err)
		// Don't fail the request if logging fails
	}

	// Check daily API usage and warn if approaching limit
	go h.checkAPIUsageLimit()

	// If request failed, return error to client
	if status != models.DistanceRequestStatusSuccess {
		statusCode := http.StatusInternalServerError
		message := "Failed to calculate distance"

		if status == models.DistanceRequestStatusRateLimited {
			statusCode = http.StatusTooManyRequests
			message = "Rate limit exceeded: Mapbox API free tier limit reached. Please try again later."
		} else if status == models.DistanceRequestStatusInvalidCoordinates {
			statusCode = http.StatusBadRequest
			message = "Invalid coordinates: Unable to find route between locations"
		}

		sendError(w, statusCode, message)
		return
	}

	// Build successful response
	response := models.DistanceEstimateResponse{
		Origin: models.AddressInfo{
			AddressID:    &address.ID,
			AddressLine1: address.AddressLine1,
			AddressLine2: address.AddressLine2,
			City:         address.City,
			State:        address.State,
			PostalCode:   address.PostalCode,
			Country:      address.Country,
			Latitude:     address.Latitude,
			Longitude:    address.Longitude,
		},
		Destination: models.RestaurantLocationInfo{
			RestaurantID: restaurant.ID,
			Name:         restaurant.Name,
			AddressLine1: restaurant.AddressLine1,
			AddressLine2: restaurant.AddressLine2,
			City:         restaurant.City,
			State:        restaurant.State,
			PostalCode:   restaurant.PostalCode,
			Country:      restaurant.Country,
			Latitude:     restaurant.Latitude,
			Longitude:    restaurant.Longitude,
		},
		Distance: models.DistanceInfo{
			Meters:     *distanceMeters,
			Miles:      services.ConvertMetersToMiles(*distanceMeters),
			Kilometers: services.ConvertMetersToKilometers(*distanceMeters),
		},
		Duration: models.DurationInfo{
			Seconds: *durationSeconds,
			Minutes: *durationSeconds / 60,
			Text:    services.FormatDuration(*durationSeconds),
		},
		CalculatedAt: time.Now(),
	}

	sendSuccess(w, http.StatusOK, "Distance calculated successfully", response)
}

// GetAPIUsage returns API usage statistics
// GET /api/distance/usage
func (h *DistanceHandler) GetAPIUsage(w http.ResponseWriter, r *http.Request) {
	// Get daily usage
	dailyUsage, err := h.App.Deps.Distance.GetDailyAPIUsage()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve daily usage", err)
		return
	}

	// Get monthly usage
	monthlyUsage, err := h.App.Deps.Distance.GetMonthlyAPIUsage()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve monthly usage", err)
		return
	}

	// Get detailed stats for last 30 days
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)
	stats, err := h.App.Deps.Distance.GetDailyAPIUsageStats(startDate, endDate)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve usage stats", err)
		return
	}

	// Calculate percentage of free tier used
	freeMonthlyLimit := 100000
	usagePercent := float64(monthlyUsage) / float64(freeMonthlyLimit) * 100

	response := map[string]interface{}{
		"daily": map[string]interface{}{
			"count": dailyUsage,
		},
		"monthly": map[string]interface{}{
			"count":           monthlyUsage,
			"limit":           freeMonthlyLimit,
			"remaining":       freeMonthlyLimit - monthlyUsage,
			"usage_percent":   fmt.Sprintf("%.2f%%", usagePercent),
			"approaching_limit": usagePercent >= 80,
		},
		"stats": stats,
	}

	sendSuccess(w, http.StatusOK, "API usage retrieved successfully", response)
}

// GetUserDistanceHistory returns recent distance requests for the authenticated user
// GET /api/distance/history
func (h *DistanceHandler) GetUserDistanceHistory(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Get pagination params (default: 50 recent requests)
	pagination := h.ParsePagination(r)
	if pagination.PerPage > 100 {
		pagination.PerPage = 100
	}

	requests, err := h.App.Deps.Distance.GetDistanceRequestsByUserID(user.UserID, pagination.PerPage)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve distance history", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Distance history retrieved successfully", requests)
}

// checkAPIUsageLimit checks if approaching Mapbox free tier limit and logs warning
func (h *DistanceHandler) checkAPIUsageLimit() {
	monthlyUsage, err := h.App.Deps.Distance.GetMonthlyAPIUsage()
	if err != nil {
		log.Printf("[ERROR] Failed to check API usage limit: %v", err)
		return
	}

	const freeMonthlyLimit = 100000
	const warningThreshold = 80000 // 80% of limit

	if monthlyUsage >= warningThreshold {
		usagePercent := float64(monthlyUsage) / float64(freeMonthlyLimit) * 100
		log.Printf("[WARNING] Mapbox API Usage Alert!\n"+
			"  Monthly Usage: %d / %d (%.2f%%)\n"+
			"  Remaining: %d requests\n"+
			"  Recommendation: Consider implementing caching or upgrading to paid tier",
			monthlyUsage, freeMonthlyLimit, usagePercent, freeMonthlyLimit-monthlyUsage)
	}
}
