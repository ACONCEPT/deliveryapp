package models

import "time"

// DistanceRequestStatus represents the outcome of a distance API request
type DistanceRequestStatus string

const (
	DistanceRequestStatusSuccess             DistanceRequestStatus = "success"
	DistanceRequestStatusError               DistanceRequestStatus = "error"
	DistanceRequestStatusRateLimited         DistanceRequestStatus = "rate_limited"
	DistanceRequestStatusInvalidCoordinates  DistanceRequestStatus = "invalid_coordinates"
	DistanceRequestStatusTimeout             DistanceRequestStatus = "timeout"
)

// DistanceRequest represents a logged distance calculation request
type DistanceRequest struct {
	ID                      int                   `json:"id" db:"id"`
	UserID                  int                   `json:"user_id" db:"user_id"`
	OriginAddressID         *int                  `json:"origin_address_id,omitempty" db:"origin_address_id"`
	DestinationRestaurantID *int                  `json:"destination_restaurant_id,omitempty" db:"destination_restaurant_id"`
	OriginLatitude          *float64              `json:"origin_latitude,omitempty" db:"origin_latitude"`
	OriginLongitude         *float64              `json:"origin_longitude,omitempty" db:"origin_longitude"`
	DestinationLatitude     *float64              `json:"destination_latitude,omitempty" db:"destination_latitude"`
	DestinationLongitude    *float64              `json:"destination_longitude,omitempty" db:"destination_longitude"`
	Status                  DistanceRequestStatus `json:"status" db:"status"`
	DistanceMeters          *int                  `json:"distance_meters,omitempty" db:"distance_meters"`
	DurationSeconds         *int                  `json:"duration_seconds,omitempty" db:"duration_seconds"`
	APIResponseTimeMs       *int                  `json:"api_response_time_ms,omitempty" db:"api_response_time_ms"`
	ErrorMessage            *string               `json:"error_message,omitempty" db:"error_message"`
	MapboxRequestID         *string               `json:"mapbox_request_id,omitempty" db:"mapbox_request_id"`
	CreatedAt               time.Time             `json:"created_at" db:"created_at"`
}

// DistanceEstimateRequest represents the API request to calculate distance
type DistanceEstimateRequest struct {
	AddressID    int `json:"address_id" validate:"required,gt=0"`
	RestaurantID int `json:"restaurant_id" validate:"required,gt=0"`
}

// AddressInfo represents location information for the response
type AddressInfo struct {
	AddressID    *int     `json:"address_id,omitempty"`
	AddressLine1 string   `json:"address_line1"`
	AddressLine2 *string  `json:"address_line2,omitempty"`
	City         string   `json:"city"`
	State        *string  `json:"state,omitempty"`
	PostalCode   *string  `json:"postal_code,omitempty"`
	Country      string   `json:"country"`
	Latitude     *float64 `json:"latitude,omitempty"`
	Longitude    *float64 `json:"longitude,omitempty"`
}

// RestaurantLocationInfo represents restaurant location information for distance response
type RestaurantLocationInfo struct {
	RestaurantID int      `json:"restaurant_id"`
	Name         string   `json:"name"`
	AddressLine1 *string  `json:"address_line1,omitempty"`
	AddressLine2 *string  `json:"address_line2,omitempty"`
	City         *string  `json:"city,omitempty"`
	State        *string  `json:"state,omitempty"`
	PostalCode   *string  `json:"postal_code,omitempty"`
	Country      *string  `json:"country,omitempty"`
	Latitude     *float64 `json:"latitude,omitempty"`
	Longitude    *float64 `json:"longitude,omitempty"`
}

// DistanceInfo represents calculated distance information
type DistanceInfo struct {
	Meters     int     `json:"meters"`
	Miles      float64 `json:"miles"`
	Kilometers float64 `json:"kilometers"`
}

// DurationInfo represents calculated duration information
type DurationInfo struct {
	Seconds int    `json:"seconds"`
	Minutes int    `json:"minutes"`
	Text    string `json:"text"`
}

// DistanceEstimateResponse represents the API response with distance and duration
type DistanceEstimateResponse struct {
	Origin       AddressInfo            `json:"origin"`
	Destination  RestaurantLocationInfo `json:"destination"`
	Distance     DistanceInfo           `json:"distance"`
	Duration     DurationInfo           `json:"duration"`
	CalculatedAt time.Time              `json:"calculated_at"`
}

// DailyAPIUsageStats represents daily Mapbox API usage statistics
type DailyAPIUsageStats struct {
	Date              string `json:"date" db:"date"`
	TotalRequests     int    `json:"total_requests" db:"total_requests"`
	SuccessfulCount   int    `json:"successful_count" db:"successful_count"`
	ErrorCount        int    `json:"error_count" db:"error_count"`
	RateLimitedCount  int    `json:"rate_limited_count" db:"rate_limited_count"`
	AvgResponseTimeMs *int   `json:"avg_response_time_ms,omitempty" db:"avg_response_time_ms"`
}

// MapboxDirectionsResponse represents the response from Mapbox Directions API
type MapboxDirectionsResponse struct {
	Routes []struct {
		Distance float64 `json:"distance"` // meters
		Duration float64 `json:"duration"` // seconds
	} `json:"routes"`
	Code    string `json:"code"`
	Message string `json:"message,omitempty"`
	UUID    string `json:"uuid,omitempty"`
}
