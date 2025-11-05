package services

import (
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

const (
	MapboxDirectionsAPIURL = "https://api.mapbox.com/directions/v5/mapbox/driving"
	MapboxTimeout          = 10 * time.Second
	MapboxMaxRetries       = 2
)

// MapboxService handles communication with Mapbox API
type MapboxService struct {
	accessToken string
	httpClient  *http.Client
}

// NewMapboxService creates a new Mapbox service instance
func NewMapboxService(accessToken string) *MapboxService {
	return &MapboxService{
		accessToken: accessToken,
		httpClient: &http.Client{
			Timeout: MapboxTimeout,
		},
	}
}

// MapboxResult contains the result of a Mapbox API call
type MapboxResult struct {
	DistanceMeters  int
	DurationSeconds int
	ResponseTimeMs  int
	RequestID       string
	Error           error
	StatusCode      int
}

// GetDrivingDistance calculates driving distance and duration between two coordinates
func (s *MapboxService) GetDrivingDistance(originLng, originLat, destLng, destLat float64) (*MapboxResult, error) {
	startTime := time.Now()

	// Validate coordinates
	if !s.isValidCoordinate(originLat, originLng) || !s.isValidCoordinate(destLat, destLng) {
		return nil, fmt.Errorf("invalid coordinates: origin(%.6f,%.6f) dest(%.6f,%.6f)",
			originLat, originLng, destLat, destLng)
	}

	// Build Mapbox URL
	// Format: /directions/v5/mapbox/driving/{lng1},{lat1};{lng2},{lat2}
	url := fmt.Sprintf("%s/%.6f,%.6f;%.6f,%.6f?access_token=%s&geometries=geojson&overview=false",
		MapboxDirectionsAPIURL,
		originLng, originLat,
		destLng, destLat,
		s.accessToken,
	)

	// Make HTTP request
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", "DeliveryApp/1.0")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	responseTime := int(time.Since(startTime).Milliseconds())
	requestID := resp.Header.Get("X-Mapbox-Request-Id")

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Handle HTTP error status codes
	if resp.StatusCode != http.StatusOK {
		return s.handleErrorResponse(resp.StatusCode, body, responseTime, requestID)
	}

	// Parse successful response
	var apiResp models.MapboxDirectionsResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	// Check API response code
	if apiResp.Code != "Ok" {
		return &MapboxResult{
			Error:          fmt.Errorf("Mapbox API error: %s - %s", apiResp.Code, apiResp.Message),
			ResponseTimeMs: responseTime,
			RequestID:      requestID,
			StatusCode:     resp.StatusCode,
		}, nil
	}

	// Check if routes are available
	if len(apiResp.Routes) == 0 {
		return &MapboxResult{
			Error:          fmt.Errorf("no routes found between coordinates"),
			ResponseTimeMs: responseTime,
			RequestID:      requestID,
			StatusCode:     resp.StatusCode,
		}, nil
	}

	// Extract distance and duration from first route
	route := apiResp.Routes[0]

	return &MapboxResult{
		DistanceMeters:  int(route.Distance),
		DurationSeconds: int(route.Duration),
		ResponseTimeMs:  responseTime,
		RequestID:       requestID,
		StatusCode:      resp.StatusCode,
		Error:           nil,
	}, nil
}

// handleErrorResponse processes Mapbox API error responses
func (s *MapboxService) handleErrorResponse(statusCode int, body []byte, responseTime int, requestID string) (*MapboxResult, error) {
	result := &MapboxResult{
		ResponseTimeMs: responseTime,
		RequestID:      requestID,
		StatusCode:     statusCode,
	}

	switch statusCode {
	case http.StatusTooManyRequests: // 429
		// Rate limit exceeded - HIGH SEVERITY
		log.Printf("[HIGH SEVERITY] Mapbox API Rate Limit Exceeded!\n"+
			"  Status: 429 Too Many Requests\n"+
			"  Request ID: %s\n"+
			"  Response Time: %dms\n"+
			"  Action Required: Review daily API usage and consider caching or paid tier\n"+
			"  Free Tier Limit: 100,000 requests/month",
			requestID, responseTime)
		result.Error = fmt.Errorf("rate limit exceeded: Mapbox API free tier limit reached (100,000 requests/month)")

	case http.StatusUnauthorized: // 401
		log.Printf("[ERROR] Mapbox API Authentication Failed\n"+
			"  Status: 401 Unauthorized\n"+
			"  Request ID: %s\n"+
			"  Error: Invalid or missing MAPBOX_ACCESS_TOKEN",
			requestID)
		result.Error = fmt.Errorf("authentication failed: invalid Mapbox access token")

	case http.StatusNotFound: // 404
		result.Error = fmt.Errorf("invalid request: route not found")

	case http.StatusUnprocessableEntity: // 422
		result.Error = fmt.Errorf("invalid coordinates: Mapbox could not process the request")

	default:
		// Try to parse error message from body
		var apiResp models.MapboxDirectionsResponse
		if err := json.Unmarshal(body, &apiResp); err == nil && apiResp.Message != "" {
			result.Error = fmt.Errorf("Mapbox API error (HTTP %d): %s", statusCode, apiResp.Message)
		} else {
			result.Error = fmt.Errorf("Mapbox API error: HTTP %d - %s", statusCode, string(body))
		}

		log.Printf("[ERROR] Mapbox API Error\n"+
			"  Status: %d\n"+
			"  Request ID: %s\n"+
			"  Response Time: %dms\n"+
			"  Body: %s",
			statusCode, requestID, responseTime, string(body))
	}

	return result, nil
}

// isValidCoordinate validates latitude and longitude ranges
func (s *MapboxService) isValidCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

// ConvertMetersToMiles converts meters to miles
func ConvertMetersToMiles(meters int) float64 {
	return float64(meters) / 1609.344
}

// ConvertMetersToKilometers converts meters to kilometers
func ConvertMetersToKilometers(meters int) float64 {
	return float64(meters) / 1000.0
}

// FormatDuration formats seconds into a human-readable string
func FormatDuration(seconds int) string {
	if seconds < 60 {
		return fmt.Sprintf("%d sec", seconds)
	}
	minutes := seconds / 60
	if minutes < 60 {
		return fmt.Sprintf("%d min", minutes)
	}
	hours := minutes / 60
	remainingMinutes := minutes % 60
	if remainingMinutes == 0 {
		return fmt.Sprintf("%d hr", hours)
	}
	return fmt.Sprintf("%d hr %d min", hours, remainingMinutes)
}
