package repositories

import (
	"delivery_app/backend/models"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

// DistanceRepository handles distance request logging and API usage tracking
type DistanceRepository interface {
	// CreateDistanceRequest logs a new distance calculation request
	CreateDistanceRequest(req *models.DistanceRequest) error

	// GetDistanceRequestByID retrieves a distance request by ID
	GetDistanceRequestByID(id int) (*models.DistanceRequest, error)

	// GetDistanceRequestsByUserID retrieves all distance requests for a user
	GetDistanceRequestsByUserID(userID int, limit int) ([]*models.DistanceRequest, error)

	// GetDailyAPIUsage returns the count of successful API calls for today
	GetDailyAPIUsage() (int, error)

	// GetDailyAPIUsageStats returns detailed usage statistics for a date range
	GetDailyAPIUsageStats(startDate, endDate time.Time) ([]*models.DailyAPIUsageStats, error)

	// GetMonthlyAPIUsage returns the count of successful API calls for current month
	GetMonthlyAPIUsage() (int, error)
}

type distanceRepository struct {
	db *sqlx.DB
}

// NewDistanceRepository creates a new DistanceRepository instance
func NewDistanceRepository(db *sqlx.DB) DistanceRepository {
	return &distanceRepository{db: db}
}

// CreateDistanceRequest logs a distance calculation request to the database
func (r *distanceRepository) CreateDistanceRequest(req *models.DistanceRequest) error {
	query := `
		INSERT INTO distance_requests (
			user_id,
			origin_address_id,
			destination_restaurant_id,
			origin_latitude,
			origin_longitude,
			destination_latitude,
			destination_longitude,
			status,
			distance_meters,
			duration_seconds,
			api_response_time_ms,
			error_message,
			mapbox_request_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		RETURNING id, created_at
	`

	args := []interface{}{
		req.UserID,
		req.OriginAddressID,
		req.DestinationRestaurantID,
		req.OriginLatitude,
		req.OriginLongitude,
		req.DestinationLatitude,
		req.DestinationLongitude,
		req.Status,
		req.DistanceMeters,
		req.DurationSeconds,
		req.APIResponseTimeMs,
		req.ErrorMessage,
		req.MapboxRequestID,
	}

	err := GetData(r.db, query, req, args)
	if err != nil {
		return fmt.Errorf("failed to create distance request: %w", err)
	}

	return nil
}

// GetDistanceRequestByID retrieves a single distance request by ID
func (r *distanceRepository) GetDistanceRequestByID(id int) (*models.DistanceRequest, error) {
	var req models.DistanceRequest

	query := `
		SELECT
			id, user_id, origin_address_id, destination_restaurant_id,
			origin_latitude, origin_longitude, destination_latitude, destination_longitude,
			status, distance_meters, duration_seconds, api_response_time_ms,
			error_message, mapbox_request_id, created_at
		FROM distance_requests
		WHERE id = $1
	`

	err := GetData(r.db, query, &req, []interface{}{id})
	if err != nil {
		return nil, fmt.Errorf("distance request not found")
	}

	return &req, nil
}

// GetDistanceRequestsByUserID retrieves recent distance requests for a user
func (r *distanceRepository) GetDistanceRequestsByUserID(userID int, limit int) ([]*models.DistanceRequest, error) {
	var requests []*models.DistanceRequest

	query := `
		SELECT
			id, user_id, origin_address_id, destination_restaurant_id,
			origin_latitude, origin_longitude, destination_latitude, destination_longitude,
			status, distance_meters, duration_seconds, api_response_time_ms,
			error_message, mapbox_request_id, created_at
		FROM distance_requests
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`

	err := SelectData(r.db, query, &requests, []interface{}{userID, limit})
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve distance requests: %w", err)
	}

	return requests, nil
}

// GetDailyAPIUsage returns the count of successful Mapbox API calls for today
func (r *distanceRepository) GetDailyAPIUsage() (int, error) {
	var count int

	query := `
		SELECT COUNT(*)
		FROM distance_requests
		WHERE status = 'success'
		  AND DATE(created_at) = CURRENT_DATE
	`

	err := r.db.Get(&count, query)
	if err != nil {
		return 0, fmt.Errorf("failed to get daily API usage: %w", err)
	}

	return count, nil
}

// GetDailyAPIUsageStats returns detailed usage statistics for a date range
func (r *distanceRepository) GetDailyAPIUsageStats(startDate, endDate time.Time) ([]*models.DailyAPIUsageStats, error) {
	var stats []*models.DailyAPIUsageStats

	query := `
		SELECT
			DATE(created_at) as date,
			COUNT(*) as total_requests,
			COUNT(*) FILTER (WHERE status = 'success') as successful_count,
			COUNT(*) FILTER (WHERE status = 'error') as error_count,
			COUNT(*) FILTER (WHERE status = 'rate_limited') as rate_limited_count,
			AVG(api_response_time_ms)::INTEGER as avg_response_time_ms
		FROM distance_requests
		WHERE DATE(created_at) BETWEEN $1 AND $2
		GROUP BY DATE(created_at)
		ORDER BY DATE(created_at) DESC
	`

	err := SelectData(r.db, query, &stats, []interface{}{startDate, endDate})
	if err != nil {
		return nil, fmt.Errorf("failed to get API usage stats: %w", err)
	}

	return stats, nil
}

// GetMonthlyAPIUsage returns the count of successful API calls for the current month
func (r *distanceRepository) GetMonthlyAPIUsage() (int, error) {
	var count int

	query := `
		SELECT COUNT(*)
		FROM distance_requests
		WHERE status = 'success'
		  AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE)
	`

	err := r.db.Get(&count, query)
	if err != nil {
		return 0, fmt.Errorf("failed to get monthly API usage: %w", err)
	}

	return count, nil
}
