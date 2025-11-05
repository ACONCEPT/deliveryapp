# Backend Development Plan: Driver Delivery Tracking

## Overview

Implement driver location tracking with geofencing, automatic arrival detection, and HTTP polling for admin dashboard updates.

---

## Phase 1: Database Schema and Models (Day 1-2)

### Step 1.1: Create Database Migration

**File:** `backend/sql/migrations/006_add_driver_location_tracking.sql`

```sql
-- Driver location status enum
DO $$ BEGIN
    CREATE TYPE driver_location_status AS ENUM ('offline', 'online', 'on_delivery', 'paused');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Real-time driver locations (current position only)
CREATE TABLE IF NOT EXISTS driver_locations (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER UNIQUE NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,

    -- Current Position
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy_meters DECIMAL(8, 2),
    altitude_meters DECIMAL(8, 2),
    heading_degrees INTEGER,
    speed_mps DECIMAL(6, 2),

    -- Status
    status driver_location_status NOT NULL DEFAULT 'offline',
    is_tracking_active BOOLEAN DEFAULT FALSE,

    -- Current Delivery Context
    current_order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
    destination_type VARCHAR(20),
    destination_lat DECIMAL(10, 8),
    destination_lng DECIMAL(11, 8),

    -- Timestamps
    location_timestamp TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Battery optimization
    battery_level INTEGER,
    is_battery_saving BOOLEAN DEFAULT FALSE,

    CONSTRAINT valid_accuracy CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0),
    CONSTRAINT valid_heading CHECK (heading_degrees IS NULL OR (heading_degrees >= 0 AND heading_degrees < 360)),
    CONSTRAINT valid_speed CHECK (speed_mps IS NULL OR speed_mps >= 0),
    CONSTRAINT valid_battery CHECK (battery_level IS NULL OR (battery_level >= 0 AND battery_level <= 100))
);

-- Location history for delivery tracking and analytics
CREATE TABLE IF NOT EXISTS location_history (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,

    -- Location Data
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy_meters DECIMAL(8, 2),
    speed_mps DECIMAL(6, 2),
    heading_degrees INTEGER,

    -- Context
    status driver_location_status NOT NULL,
    event_type VARCHAR(50),

    -- Timestamps
    recorded_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT valid_accuracy_history CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0)
);

-- Geofence arrival/departure events
CREATE TABLE IF NOT EXISTS geofence_events (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Geofence Details
    location_type VARCHAR(20) NOT NULL,
    location_id INTEGER NOT NULL,
    target_latitude DECIMAL(10, 8) NOT NULL,
    target_longitude DECIMAL(11, 8) NOT NULL,

    -- Driver Position at Event
    driver_latitude DECIMAL(10, 8) NOT NULL,
    driver_longitude DECIMAL(11, 8) NOT NULL,
    distance_meters INTEGER NOT NULL,

    -- Event Details
    event_type VARCHAR(20) NOT NULL,
    threshold_meters INTEGER NOT NULL,
    confidence_score DECIMAL(3, 2),

    -- Timestamps
    detected_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT valid_location_type CHECK (location_type IN ('restaurant', 'customer')),
    CONSTRAINT valid_event_type CHECK (event_type IN ('arrival', 'departure')),
    CONSTRAINT valid_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1))
);

-- Tracking session lifecycle
CREATE TABLE IF NOT EXISTS tracking_sessions (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,

    -- Session Details
    session_token UUID NOT NULL DEFAULT uuid_generate_v4(),
    status VARCHAR(20) NOT NULL,

    -- Metrics
    start_location_lat DECIMAL(10, 8),
    start_location_lng DECIMAL(11, 8),
    end_location_lat DECIMAL(10, 8),
    end_location_lng DECIMAL(11, 8),
    total_distance_meters INTEGER,
    total_duration_seconds INTEGER,
    location_update_count INTEGER DEFAULT 0,

    -- Timestamps
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT valid_session_status CHECK (status IN ('active', 'paused', 'completed', 'failed'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_id ON driver_locations(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_status ON driver_locations(status);
CREATE INDEX IF NOT EXISTS idx_driver_locations_order_id ON driver_locations(current_order_id) WHERE current_order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_driver_locations_tracking_active ON driver_locations(is_tracking_active) WHERE is_tracking_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_driver_locations_updated_at ON driver_locations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_locations_map_query ON driver_locations(status, is_tracking_active, updated_at DESC) WHERE is_tracking_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_location_history_driver_id ON location_history(driver_id);
CREATE INDEX IF NOT EXISTS idx_location_history_order_id ON location_history(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_location_history_recorded_at ON location_history(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_history_driver_order ON location_history(driver_id, order_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_history_event_type ON location_history(event_type);

CREATE INDEX IF NOT EXISTS idx_geofence_events_driver_id ON geofence_events(driver_id);
CREATE INDEX IF NOT EXISTS idx_geofence_events_order_id ON geofence_events(order_id);
CREATE INDEX IF NOT EXISTS idx_geofence_events_detected_at ON geofence_events(detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_geofence_events_location ON geofence_events(location_type, location_id);

CREATE INDEX IF NOT EXISTS idx_tracking_sessions_driver_id ON tracking_sessions(driver_id);
CREATE INDEX IF NOT EXISTS idx_tracking_sessions_order_id ON tracking_sessions(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tracking_sessions_status ON tracking_sessions(status);
CREATE INDEX IF NOT EXISTS idx_tracking_sessions_started_at ON tracking_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_tracking_sessions_active ON tracking_sessions(driver_id, status) WHERE status = 'active';

-- Triggers for automation
CREATE OR REPLACE FUNCTION log_location_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO location_history (
        driver_id, order_id, latitude, longitude,
        accuracy_meters, speed_mps, heading_degrees,
        status, event_type, recorded_at
    ) VALUES (
        NEW.driver_id, NEW.current_order_id, NEW.latitude, NEW.longitude,
        NEW.accuracy_meters, NEW.speed_mps, NEW.heading_degrees,
        NEW.status, 'location_update', NEW.location_timestamp
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_log_location_history ON driver_locations;
CREATE TRIGGER trigger_log_location_history
    AFTER INSERT OR UPDATE OF latitude, longitude ON driver_locations
    FOR EACH ROW
    EXECUTE FUNCTION log_location_history();

CREATE OR REPLACE FUNCTION increment_session_update_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE tracking_sessions
    SET
        location_update_count = location_update_count + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE driver_id = NEW.driver_id AND status = 'active';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_increment_session_count ON driver_locations;
CREATE TRIGGER trigger_increment_session_count
    AFTER INSERT OR UPDATE OF latitude, longitude ON driver_locations
    FOR EACH ROW
    EXECUTE FUNCTION increment_session_update_count();

-- Data retention function (run daily via cron)
CREATE OR REPLACE FUNCTION archive_old_location_history(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM location_history
    WHERE recorded_at < NOW() - INTERVAL '1 day' * days_to_keep
      AND event_type = 'location_update'
    RETURNING COUNT(*) INTO deleted_count;

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
```

**Testing:**
```bash
# Run migration
cd backend
psql $DATABASE_URL -f sql/migrations/006_add_driver_location_tracking.sql

# Verify tables created
psql $DATABASE_URL -c "\dt driver_locations location_history geofence_events tracking_sessions"

# Verify indexes
psql $DATABASE_URL -c "\di idx_driver_locations*"
```

### Step 1.2: Create Go Models

**File:** `backend/models/tracking.go`

```go
package models

import "time"

// DriverLocationStatus represents driver's current tracking state
type DriverLocationStatus string

const (
	DriverLocationStatusOffline   DriverLocationStatus = "offline"
	DriverLocationStatusOnline    DriverLocationStatus = "online"
	DriverLocationStatusOnDelivery DriverLocationStatus = "on_delivery"
	DriverLocationStatusPaused    DriverLocationStatus = "paused"
)

// DriverLocation represents real-time driver location
type DriverLocation struct {
	ID                int                   `json:"id" db:"id"`
	DriverID          int                   `json:"driver_id" db:"driver_id"`
	Latitude          float64               `json:"latitude" db:"latitude"`
	Longitude         float64               `json:"longitude" db:"longitude"`
	AccuracyMeters    *float64              `json:"accuracy_meters,omitempty" db:"accuracy_meters"`
	AltitudeMeters    *float64              `json:"altitude_meters,omitempty" db:"altitude_meters"`
	HeadingDegrees    *int                  `json:"heading_degrees,omitempty" db:"heading_degrees"`
	SpeedMps          *float64              `json:"speed_mps,omitempty" db:"speed_mps"`
	Status            DriverLocationStatus  `json:"status" db:"status"`
	IsTrackingActive  bool                  `json:"is_tracking_active" db:"is_tracking_active"`
	CurrentOrderID    *int                  `json:"current_order_id,omitempty" db:"current_order_id"`
	DestinationType   *string               `json:"destination_type,omitempty" db:"destination_type"`
	DestinationLat    *float64              `json:"destination_lat,omitempty" db:"destination_lat"`
	DestinationLng    *float64              `json:"destination_lng,omitempty" db:"destination_lng"`
	LocationTimestamp time.Time             `json:"location_timestamp" db:"location_timestamp"`
	BatteryLevel      *int                  `json:"battery_level,omitempty" db:"battery_level"`
	IsBatterySaving   bool                  `json:"is_battery_saving" db:"is_battery_saving"`
	UpdatedAt         time.Time             `json:"updated_at" db:"updated_at"`
	CreatedAt         time.Time             `json:"created_at" db:"created_at"`
}

// LocationHistory represents historical location point
type LocationHistory struct {
	ID             int                   `json:"id" db:"id"`
	DriverID       int                   `json:"driver_id" db:"driver_id"`
	OrderID        *int                  `json:"order_id,omitempty" db:"order_id"`
	Latitude       float64               `json:"latitude" db:"latitude"`
	Longitude      float64               `json:"longitude" db:"longitude"`
	AccuracyMeters *float64              `json:"accuracy_meters,omitempty" db:"accuracy_meters"`
	SpeedMps       *float64              `json:"speed_mps,omitempty" db:"speed_mps"`
	HeadingDegrees *int                  `json:"heading_degrees,omitempty" db:"heading_degrees"`
	Status         DriverLocationStatus  `json:"status" db:"status"`
	EventType      *string               `json:"event_type,omitempty" db:"event_type"`
	RecordedAt     time.Time             `json:"recorded_at" db:"recorded_at"`
	CreatedAt      time.Time             `json:"created_at" db:"created_at"`
}

// GeofenceEvent represents arrival/departure detection
type GeofenceEvent struct {
	ID              int       `json:"id" db:"id"`
	DriverID        int       `json:"driver_id" db:"driver_id"`
	OrderID         int       `json:"order_id" db:"order_id"`
	LocationType    string    `json:"location_type" db:"location_type"`
	LocationID      int       `json:"location_id" db:"location_id"`
	TargetLatitude  float64   `json:"target_latitude" db:"target_latitude"`
	TargetLongitude float64   `json:"target_longitude" db:"target_longitude"`
	DriverLatitude  float64   `json:"driver_latitude" db:"driver_latitude"`
	DriverLongitude float64   `json:"driver_longitude" db:"driver_longitude"`
	DistanceMeters  int       `json:"distance_meters" db:"distance_meters"`
	EventType       string    `json:"event_type" db:"event_type"`
	ThresholdMeters int       `json:"threshold_meters" db:"threshold_meters"`
	ConfidenceScore *float64  `json:"confidence_score,omitempty" db:"confidence_score"`
	DetectedAt      time.Time `json:"detected_at" db:"detected_at"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
}

// TrackingSession represents active tracking session
type TrackingSession struct {
	ID                   int        `json:"id" db:"id"`
	DriverID             int        `json:"driver_id" db:"driver_id"`
	OrderID              *int       `json:"order_id,omitempty" db:"order_id"`
	SessionToken         string     `json:"session_token" db:"session_token"`
	Status               string     `json:"status" db:"status"`
	StartLocationLat     *float64   `json:"start_location_lat,omitempty" db:"start_location_lat"`
	StartLocationLng     *float64   `json:"start_location_lng,omitempty" db:"start_location_lng"`
	EndLocationLat       *float64   `json:"end_location_lat,omitempty" db:"end_location_lat"`
	EndLocationLng       *float64   `json:"end_location_lng,omitempty" db:"end_location_lng"`
	TotalDistanceMeters  *int       `json:"total_distance_meters,omitempty" db:"total_distance_meters"`
	TotalDurationSeconds *int       `json:"total_duration_seconds,omitempty" db:"total_duration_seconds"`
	LocationUpdateCount  int        `json:"location_update_count" db:"location_update_count"`
	StartedAt            time.Time  `json:"started_at" db:"started_at"`
	EndedAt              *time.Time `json:"ended_at,omitempty" db:"ended_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
}

// Request/Response DTOs

// UpdateLocationRequest - Mobile app sends location updates
type UpdateLocationRequest struct {
	Latitude          float64  `json:"latitude" validate:"required"`
	Longitude         float64  `json:"longitude" validate:"required"`
	AccuracyMeters    *float64 `json:"accuracy_meters,omitempty"`
	AltitudeMeters    *float64 `json:"altitude_meters,omitempty"`
	HeadingDegrees    *int     `json:"heading_degrees,omitempty"`
	SpeedMps          *float64 `json:"speed_mps,omitempty"`
	LocationTimestamp string   `json:"location_timestamp" validate:"required"`
	BatteryLevel      *int     `json:"battery_level,omitempty"`
}

// StartTrackingRequest - Driver starts tracking session
type StartTrackingRequest struct {
	OrderID *int `json:"order_id,omitempty"`
}

// DriverLocationResponse - Public response for driver location
type DriverLocationResponse struct {
	DriverID       int                  `json:"driver_id"`
	DriverName     string               `json:"driver_name"`
	Latitude       float64              `json:"latitude"`
	Longitude      float64              `json:"longitude"`
	HeadingDegrees *int                 `json:"heading_degrees,omitempty"`
	SpeedMps       *float64             `json:"speed_mps,omitempty"`
	Status         DriverLocationStatus `json:"status"`
	OrderID        *int                 `json:"order_id,omitempty"`
	Destination    *DestinationInfo     `json:"destination,omitempty"`
	UpdatedAt      time.Time            `json:"updated_at"`
}

// DestinationInfo - Where driver is heading
type DestinationInfo struct {
	Type       string  `json:"type"`
	Name       string  `json:"name"`
	Latitude   float64 `json:"latitude"`
	Longitude  float64 `json:"longitude"`
	ETAMinutes *int    `json:"eta_minutes,omitempty"`
}

// ActiveDriversResponse - Admin dashboard response
type ActiveDriversResponse struct {
	TotalActive int                      `json:"total_active"`
	OnDelivery  int                      `json:"on_delivery"`
	Drivers     []DriverLocationResponse `json:"drivers"`
	UpdatedAt   time.Time                `json:"updated_at"`
}

// LocationHistoryResponse - Trail for specific delivery
type LocationHistoryResponse struct {
	OrderID    int                    `json:"order_id"`
	DriverID   int                    `json:"driver_id"`
	DriverName string                 `json:"driver_name"`
	StartTime  time.Time              `json:"start_time"`
	EndTime    *time.Time             `json:"end_time,omitempty"`
	Points     []LocationHistoryPoint `json:"points"`
	Events     []GeofenceEvent        `json:"events"`
}

// LocationHistoryPoint - Single point in trail
type LocationHistoryPoint struct {
	Latitude   float64   `json:"latitude"`
	Longitude  float64   `json:"longitude"`
	SpeedMps   *float64  `json:"speed_mps,omitempty"`
	Heading    *int      `json:"heading_degrees,omitempty"`
	RecordedAt time.Time `json:"recorded_at"`
	EventType  *string   `json:"event_type,omitempty"`
}
```

**Testing:**
```bash
# Compile check
cd backend
go build -o /dev/null ./models/tracking.go
```

---

## Phase 2: Repository Layer (Day 3-4)

### Step 2.1: Create Tracking Repository

**File:** `backend/repositories/tracking_repository.go`

```go
package repositories

import (
	"delivery_app/backend/models"
	"time"

	"github.com/jmoiron/sqlx"
)

type TrackingRepository interface {
	// Driver Location Operations
	UpsertDriverLocation(location *models.DriverLocation) error
	GetDriverLocation(driverID int) (*models.DriverLocation, error)
	GetActiveDriverLocations() ([]models.DriverLocation, error)
	GetDriverLocationsByStatus(status models.DriverLocationStatus) ([]models.DriverLocation, error)
	UpdateDriverStatus(driverID int, status models.DriverLocationStatus) error

	// Location History
	CreateLocationHistory(history *models.LocationHistory) error
	GetLocationHistoryByOrder(orderID int) ([]models.LocationHistory, error)
	GetLocationHistoryByDriver(driverID int, startTime, endTime time.Time) ([]models.LocationHistory, error)

	// Geofencing
	CreateGeofenceEvent(event *models.GeofenceEvent) error
	GetGeofenceEventsByOrder(orderID int) ([]models.GeofenceEvent, error)
	CheckRecentArrival(driverID int, orderID int, locationType string, thresholdSeconds int) (bool, error)

	// Tracking Sessions
	CreateTrackingSession(session *models.TrackingSession) error
	GetActiveSession(driverID int) (*models.TrackingSession, error)
	EndTrackingSession(sessionID int, endLat, endLng float64, totalDistance, totalDuration int) error
	UpdateSessionMetrics(sessionID int) error
}

type trackingRepository struct {
	db *sqlx.DB
}

func NewTrackingRepository(db *sqlx.DB) TrackingRepository {
	return &trackingRepository{db: db}
}

// UpsertDriverLocation - Insert or update current driver location (atomic operation)
func (r *trackingRepository) UpsertDriverLocation(location *models.DriverLocation) error {
	query := `
		INSERT INTO driver_locations (
			driver_id, latitude, longitude, accuracy_meters, altitude_meters,
			heading_degrees, speed_mps, status, is_tracking_active,
			current_order_id, destination_type, destination_lat, destination_lng,
			location_timestamp, battery_level, is_battery_saving
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
		)
		ON CONFLICT (driver_id)
		DO UPDATE SET
			latitude = EXCLUDED.latitude,
			longitude = EXCLUDED.longitude,
			accuracy_meters = EXCLUDED.accuracy_meters,
			altitude_meters = EXCLUDED.altitude_meters,
			heading_degrees = EXCLUDED.heading_degrees,
			speed_mps = EXCLUDED.speed_mps,
			status = EXCLUDED.status,
			is_tracking_active = EXCLUDED.is_tracking_active,
			current_order_id = EXCLUDED.current_order_id,
			destination_type = EXCLUDED.destination_type,
			destination_lat = EXCLUDED.destination_lat,
			destination_lng = EXCLUDED.destination_lng,
			location_timestamp = EXCLUDED.location_timestamp,
			battery_level = EXCLUDED.battery_level,
			is_battery_saving = EXCLUDED.is_battery_saving,
			updated_at = CURRENT_TIMESTAMP
		RETURNING id, created_at, updated_at
	`

	return r.db.QueryRowx(query,
		location.DriverID, location.Latitude, location.Longitude,
		location.AccuracyMeters, location.AltitudeMeters,
		location.HeadingDegrees, location.SpeedMps, location.Status,
		location.IsTrackingActive, location.CurrentOrderID,
		location.DestinationType, location.DestinationLat, location.DestinationLng,
		location.LocationTimestamp, location.BatteryLevel, location.IsBatterySaving,
	).Scan(&location.ID, &location.CreatedAt, &location.UpdatedAt)
}

// GetDriverLocation - Get current location for specific driver
func (r *trackingRepository) GetDriverLocation(driverID int) (*models.DriverLocation, error) {
	query := `SELECT * FROM driver_locations WHERE driver_id = $1`

	var location models.DriverLocation
	err := r.db.Get(&location, query, driverID)
	if err != nil {
		return nil, err
	}
	return &location, nil
}

// GetActiveDriverLocations - Get all drivers currently tracking
func (r *trackingRepository) GetActiveDriverLocations() ([]models.DriverLocation, error) {
	query := `
		SELECT * FROM driver_locations
		WHERE is_tracking_active = TRUE
		  AND updated_at > NOW() - INTERVAL '5 minutes'
		ORDER BY updated_at DESC
	`

	var locations []models.DriverLocation
	err := r.db.Select(&locations, query)
	return locations, err
}

// GetDriverLocationsByStatus - Filter drivers by status
func (r *trackingRepository) GetDriverLocationsByStatus(status models.DriverLocationStatus) ([]models.DriverLocation, error) {
	query := `
		SELECT * FROM driver_locations
		WHERE status = $1 AND is_tracking_active = TRUE
		ORDER BY updated_at DESC
	`

	var locations []models.DriverLocation
	err := r.db.Select(&locations, query, status)
	return locations, err
}

// UpdateDriverStatus - Change driver status
func (r *trackingRepository) UpdateDriverStatus(driverID int, status models.DriverLocationStatus) error {
	query := `
		UPDATE driver_locations
		SET status = $1, updated_at = CURRENT_TIMESTAMP
		WHERE driver_id = $2
	`

	_, err := r.db.Exec(query, status, driverID)
	return err
}

// CreateLocationHistory - Manually create history record (trigger also does this)
func (r *trackingRepository) CreateLocationHistory(history *models.LocationHistory) error {
	query := `
		INSERT INTO location_history (
			driver_id, order_id, latitude, longitude, accuracy_meters,
			speed_mps, heading_degrees, status, event_type, recorded_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at
	`

	return r.db.QueryRowx(query,
		history.DriverID, history.OrderID, history.Latitude, history.Longitude,
		history.AccuracyMeters, history.SpeedMps, history.HeadingDegrees,
		history.Status, history.EventType, history.RecordedAt,
	).Scan(&history.ID, &history.CreatedAt)
}

// GetLocationHistoryByOrder - Get trail for specific order
func (r *trackingRepository) GetLocationHistoryByOrder(orderID int) ([]models.LocationHistory, error) {
	query := `
		SELECT * FROM location_history
		WHERE order_id = $1
		ORDER BY recorded_at ASC
	`

	var history []models.LocationHistory
	err := r.db.Select(&history, query, orderID)
	return history, err
}

// GetLocationHistoryByDriver - Get driver history in time range
func (r *trackingRepository) GetLocationHistoryByDriver(driverID int, startTime, endTime time.Time) ([]models.LocationHistory, error) {
	query := `
		SELECT * FROM location_history
		WHERE driver_id = $1
		  AND recorded_at BETWEEN $2 AND $3
		ORDER BY recorded_at ASC
	`

	var history []models.LocationHistory
	err := r.db.Select(&history, query, driverID, startTime, endTime)
	return history, err
}

// CreateGeofenceEvent - Log arrival/departure
func (r *trackingRepository) CreateGeofenceEvent(event *models.GeofenceEvent) error {
	query := `
		INSERT INTO geofence_events (
			driver_id, order_id, location_type, location_id,
			target_latitude, target_longitude, driver_latitude, driver_longitude,
			distance_meters, event_type, threshold_meters, confidence_score, detected_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		RETURNING id, created_at
	`

	return r.db.QueryRowx(query,
		event.DriverID, event.OrderID, event.LocationType, event.LocationID,
		event.TargetLatitude, event.TargetLongitude, event.DriverLatitude, event.DriverLongitude,
		event.DistanceMeters, event.EventType, event.ThresholdMeters, event.ConfidenceScore, event.DetectedAt,
	).Scan(&event.ID, &event.CreatedAt)
}

// GetGeofenceEventsByOrder - Get all geofence events for order
func (r *trackingRepository) GetGeofenceEventsByOrder(orderID int) ([]models.GeofenceEvent, error) {
	query := `
		SELECT * FROM geofence_events
		WHERE order_id = $1
		ORDER BY detected_at ASC
	`

	var events []models.GeofenceEvent
	err := r.db.Select(&events, query, orderID)
	return events, err
}

// CheckRecentArrival - Prevent duplicate arrival events
func (r *trackingRepository) CheckRecentArrival(driverID int, orderID int, locationType string, thresholdSeconds int) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM geofence_events
			WHERE driver_id = $1
			  AND order_id = $2
			  AND location_type = $3
			  AND event_type = 'arrival'
			  AND detected_at > NOW() - INTERVAL '1 second' * $4
		)
	`

	var exists bool
	err := r.db.Get(&exists, query, driverID, orderID, locationType, thresholdSeconds)
	return exists, err
}

// CreateTrackingSession - Start new tracking session
func (r *trackingRepository) CreateTrackingSession(session *models.TrackingSession) error {
	query := `
		INSERT INTO tracking_sessions (
			driver_id, order_id, status, start_location_lat, start_location_lng
		) VALUES ($1, $2, $3, $4, $5)
		RETURNING id, session_token, started_at, updated_at
	`

	return r.db.QueryRowx(query,
		session.DriverID, session.OrderID, session.Status,
		session.StartLocationLat, session.StartLocationLng,
	).Scan(&session.ID, &session.SessionToken, &session.StartedAt, &session.UpdatedAt)
}

// GetActiveSession - Get driver's active session
func (r *trackingRepository) GetActiveSession(driverID int) (*models.TrackingSession, error) {
	query := `
		SELECT * FROM tracking_sessions
		WHERE driver_id = $1 AND status = 'active'
		ORDER BY started_at DESC
		LIMIT 1
	`

	var session models.TrackingSession
	err := r.db.Get(&session, query, driverID)
	if err != nil {
		return nil, err
	}
	return &session, nil
}

// EndTrackingSession - Complete tracking session
func (r *trackingRepository) EndTrackingSession(sessionID int, endLat, endLng float64, totalDistance, totalDuration int) error {
	query := `
		UPDATE tracking_sessions
		SET status = 'completed',
		    end_location_lat = $1,
		    end_location_lng = $2,
		    total_distance_meters = $3,
		    total_duration_seconds = $4,
		    ended_at = CURRENT_TIMESTAMP,
		    updated_at = CURRENT_TIMESTAMP
		WHERE id = $5
	`

	_, err := r.db.Exec(query, endLat, endLng, totalDistance, totalDuration, sessionID)
	return err
}

// UpdateSessionMetrics - Recalculate session metrics
func (r *trackingRepository) UpdateSessionMetrics(sessionID int) error {
	// This could calculate total distance from location_history
	// For now, just update timestamp
	query := `UPDATE tracking_sessions SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`
	_, err := r.db.Exec(query, sessionID)
	return err
}
```

**Testing:**
```bash
# Create test file: backend/repositories/tracking_repository_test.go
go test ./repositories -v -run TestTrackingRepository
```

---

## Phase 3: Geofencing Service (Day 5-6)

### Step 3.1: Create Geofencing Service

**File:** `backend/services/geofencing_service.go`

```go
package services

import (
	"delivery_app/backend/models"
	"delivery_app/backend/repositories"
	"log"
	"math"
	"time"
)

type GeofencingService struct {
	trackingRepo     repositories.TrackingRepository
	restaurantRepo   repositories.RestaurantRepository
	addressRepo      repositories.AddressRepository
	orderRepo        repositories.OrderRepository

	// Configuration
	restaurantRadiusMeters int
	customerRadiusMeters   int
}

func NewGeofencingService(
	trackingRepo repositories.TrackingRepository,
	restaurantRepo repositories.RestaurantRepository,
	addressRepo repositories.AddressRepository,
	orderRepo repositories.OrderRepository,
	restaurantRadius int,
	customerRadius int,
) *GeofencingService {
	return &GeofencingService{
		trackingRepo:           trackingRepo,
		restaurantRepo:         restaurantRepo,
		addressRepo:            addressRepo,
		orderRepo:              orderRepo,
		restaurantRadiusMeters: restaurantRadius,
		customerRadiusMeters:   customerRadius,
	}
}

// CalculateDistance - Haversine formula to calculate distance between two coordinates
func CalculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusMeters = 6371000.0

	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLat := (lat2 - lat1) * math.Pi / 180
	deltaLon := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLon/2)*math.Sin(deltaLon/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusMeters * c
}

// CheckArrival - Detects if driver has arrived at destination
func (s *GeofencingService) CheckArrival(
	driverID int,
	orderID int,
	driverLat, driverLng float64,
	accuracyMeters *float64,
	speedMps *float64,
) (*models.GeofenceEvent, error) {
	// Fetch order details to get destination
	order, err := s.orderRepo.GetByID(orderID)
	if err != nil {
		return nil, err
	}

	// Determine expected destination based on order status
	var targetLat, targetLng float64
	var locationType string
	var locationID int
	var thresholdMeters int

	switch order.Status {
	case models.OrderStatusDriverAssigned, models.OrderStatusInTransit:
		// Driver heading to restaurant for pickup
		restaurant, err := s.restaurantRepo.GetByID(order.RestaurantID)
		if err != nil {
			return nil, err
		}
		if restaurant.Latitude == nil || restaurant.Longitude == nil {
			return nil, nil // No coordinates, can't geofence
		}
		targetLat = *restaurant.Latitude
		targetLng = *restaurant.Longitude
		locationType = "restaurant"
		locationID = order.RestaurantID
		thresholdMeters = s.restaurantRadiusMeters

	case models.OrderStatusPickedUp:
		// Driver heading to customer for delivery
		if order.DeliveryAddressID == nil {
			return nil, nil
		}
		address, err := s.addressRepo.GetByID(*order.DeliveryAddressID)
		if err != nil {
			return nil, err
		}
		if address.Latitude == nil || address.Longitude == nil {
			return nil, nil
		}
		targetLat = *address.Latitude
		targetLng = *address.Longitude
		locationType = "customer"
		locationID = *order.DeliveryAddressID
		thresholdMeters = s.customerRadiusMeters

	default:
		// Order not in a state where arrival detection is needed
		return nil, nil
	}

	// Calculate distance
	distance := CalculateDistance(driverLat, driverLng, targetLat, targetLng)

	// Adjust threshold based on GPS accuracy
	effectiveThreshold := float64(thresholdMeters)
	if accuracyMeters != nil && *accuracyMeters > 20 {
		effectiveThreshold += *accuracyMeters // Be more lenient with poor GPS
	}

	// Check if within geofence
	if distance > effectiveThreshold {
		return nil, nil // Not arrived yet
	}

	// Calculate confidence score based on accuracy and speed
	confidence := 1.0
	if accuracyMeters != nil {
		confidence -= (*accuracyMeters / 50.0) * 0.3 // Reduce confidence for poor accuracy
	}
	if speedMps != nil && *speedMps > 2.0 { // Moving faster than 2 m/s (7.2 km/h)
		confidence -= 0.2 // Reduce confidence if still moving
	}
	if confidence < 0.0 {
		confidence = 0.0
	}

	// Check for duplicate arrival (prevent spam)
	recentArrival, err := s.trackingRepo.CheckRecentArrival(driverID, orderID, locationType, 300) // 5 min window
	if err != nil {
		return nil, err
	}
	if recentArrival {
		log.Printf("[Geofence] Duplicate arrival ignored for driver %d, order %d, type %s", driverID, orderID, locationType)
		return nil, nil // Already detected arrival recently
	}

	// Create geofence event
	event := &models.GeofenceEvent{
		DriverID:        driverID,
		OrderID:         orderID,
		LocationType:    locationType,
		LocationID:      locationID,
		TargetLatitude:  targetLat,
		TargetLongitude: targetLng,
		DriverLatitude:  driverLat,
		DriverLongitude: driverLng,
		DistanceMeters:  int(distance),
		EventType:       "arrival",
		ThresholdMeters: thresholdMeters,
		ConfidenceScore: &confidence,
		DetectedAt:      time.Now(),
	}

	// Save event
	err = s.trackingRepo.CreateGeofenceEvent(event)
	if err != nil {
		return nil, err
	}

	log.Printf("[Geofence] Arrival detected: driver %d at %s (distance: %.1fm, confidence: %.2f)",
		driverID, locationType, distance, confidence)

	return event, nil
}

// TriggerStatusUpdate - Automatically update order status on arrival
func (s *GeofencingService) TriggerStatusUpdate(event *models.GeofenceEvent) error {
	order, err := s.orderRepo.GetByID(event.OrderID)
	if err != nil {
		return err
	}

	var newStatus models.OrderStatus

	switch event.LocationType {
	case "restaurant":
		if order.Status == models.OrderStatusDriverAssigned || order.Status == models.OrderStatusInTransit {
			newStatus = models.OrderStatusPickedUp
			log.Printf("[Geofence] Auto-updating order %d status: %s -> %s", event.OrderID, order.Status, newStatus)
		}
	case "customer":
		if order.Status == models.OrderStatusPickedUp {
			newStatus = models.OrderStatusDelivered
			log.Printf("[Geofence] Auto-updating order %d status: %s -> %s", event.OrderID, order.Status, newStatus)
		}
	}

	if newStatus != "" {
		return s.orderRepo.UpdateStatus(event.OrderID, newStatus)
	}

	return nil
}
```

**Environment Variables:**

Add to `backend/.env.example`:
```bash
# Geofencing Configuration
GEOFENCE_RESTAURANT_RADIUS=100  # meters
GEOFENCE_CUSTOMER_RADIUS=50     # meters
```

**Testing:**
```bash
# Create test: backend/services/geofencing_service_test.go
go test ./services -v -run TestGeofencingService
```

---

## Phase 4: API Handlers (Day 7-9)

### Step 4.1: Create Tracking Handler

**File:** `backend/handlers/tracking.go`

```go
package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"delivery_app/backend/services"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

type TrackingHandler struct {
	*Handler
	geofencingService *services.GeofencingService
}

func NewTrackingHandler(h *Handler, geofencingService *services.GeofencingService) *TrackingHandler {
	return &TrackingHandler{
		Handler:           h,
		geofencingService: geofencingService,
	}
}

// UpdateLocation - Driver app posts location update
// POST /api/driver/location
func (h *TrackingHandler) UpdateLocation(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Verify user is a driver
	if user.UserType != models.UserTypeDriver {
		sendError(w, http.StatusForbidden, "Only drivers can update location")
		return
	}

	// Get driver record
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve driver", err)
		return
	}

	// Parse request
	var req models.UpdateLocationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate coordinates
	if req.Latitude < -90 || req.Latitude > 90 || req.Longitude < -180 || req.Longitude > 180 {
		sendError(w, http.StatusBadRequest, "Invalid coordinates")
		return
	}

	// Parse timestamp
	locationTime, err := time.Parse(time.RFC3339, req.LocationTimestamp)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid timestamp format (use ISO8601/RFC3339)")
		return
	}

	// Check if driver has active tracking session
	session, _ := h.App.Deps.Tracking.GetActiveSession(driver.ID)

	// Determine current order and destination from session
	var currentOrderID *int
	var destinationType *string
	var destinationLat, destinationLng *float64
	var status models.DriverLocationStatus = models.DriverLocationStatusOnline

	if session != nil && session.OrderID != nil {
		currentOrderID = session.OrderID
		status = models.DriverLocationStatusOnDelivery

		// TODO: Fetch order to determine destination coordinates
		// This would query restaurant or address based on order status
	}

	// Create location record
	location := &models.DriverLocation{
		DriverID:          driver.ID,
		Latitude:          req.Latitude,
		Longitude:         req.Longitude,
		AccuracyMeters:    req.AccuracyMeters,
		AltitudeMeters:    req.AltitudeMeters,
		HeadingDegrees:    req.HeadingDegrees,
		SpeedMps:          req.SpeedMps,
		Status:            status,
		IsTrackingActive:  true,
		CurrentOrderID:    currentOrderID,
		DestinationType:   destinationType,
		DestinationLat:    destinationLat,
		DestinationLng:    destinationLng,
		LocationTimestamp: locationTime,
		BatteryLevel:      req.BatteryLevel,
		IsBatterySaving:   req.BatteryLevel != nil && *req.BatteryLevel < 20,
	}

	// Save to database (upsert)
	if err := h.App.Deps.Tracking.UpsertDriverLocation(location); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update location", err)
		return
	}

	// Check for geofence arrival (if on active delivery)
	if currentOrderID != nil {
		geofenceEvent, err := h.geofencingService.CheckArrival(
			driver.ID, *currentOrderID, req.Latitude, req.Longitude,
			req.AccuracyMeters, req.SpeedMps,
		)
		if err != nil {
			log.Printf("[WARNING] Geofence check failed: %v", err)
		} else if geofenceEvent != nil {
			log.Printf("[INFO] Driver %d arrived at %s (confidence: %.2f)",
				driver.ID, geofenceEvent.LocationType, *geofenceEvent.ConfidenceScore)

			// Optionally auto-update order status
			if *geofenceEvent.ConfidenceScore >= 0.7 {
				if err := h.geofencingService.TriggerStatusUpdate(geofenceEvent); err != nil {
					log.Printf("[ERROR] Failed to auto-update order status: %v", err)
				}
			}
		}
	}

	sendSuccess(w, http.StatusOK, "Location updated successfully", map[string]interface{}{
		"location_id": location.ID,
		"updated_at":  location.UpdatedAt,
	})
}

// GetActiveDrivers - Admin dashboard: Get all active drivers
// GET /api/admin/tracking/active-drivers
func (h *TrackingHandler) GetActiveDrivers(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	if user.UserType != models.UserTypeAdmin {
		sendError(w, http.StatusForbidden, "Admin access required")
		return
	}

	locations, err := h.App.Deps.Tracking.GetActiveDriverLocations()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve active drivers", err)
		return
	}

	// Build response with driver details
	var drivers []models.DriverLocationResponse
	totalActive := 0
	onDelivery := 0

	for _, loc := range locations {
		driver, err := h.App.Deps.Users.GetDriverByID(loc.DriverID)
		if err != nil {
			continue // Skip if driver not found
		}

		totalActive++
		if loc.Status == models.DriverLocationStatusOnDelivery {
			onDelivery++
		}

		driverResp := models.DriverLocationResponse{
			DriverID:       loc.DriverID,
			DriverName:     driver.FullName,
			Latitude:       loc.Latitude,
			Longitude:      loc.Longitude,
			HeadingDegrees: loc.HeadingDegrees,
			SpeedMps:       loc.SpeedMps,
			Status:         loc.Status,
			OrderID:        loc.CurrentOrderID,
			UpdatedAt:      loc.UpdatedAt,
		}

		// Add destination info if available
		if loc.DestinationType != nil && loc.DestinationLat != nil && loc.DestinationLng != nil {
			driverResp.Destination = &models.DestinationInfo{
				Type:      *loc.DestinationType,
				Latitude:  *loc.DestinationLat,
				Longitude: *loc.DestinationLng,
			}
			// TODO: Fetch destination name and calculate ETA
		}

		drivers = append(drivers, driverResp)
	}

	response := models.ActiveDriversResponse{
		TotalActive: totalActive,
		OnDelivery:  onDelivery,
		Drivers:     drivers,
		UpdatedAt:   time.Now(),
	}

	sendSuccess(w, http.StatusOK, "Active drivers retrieved successfully", response)
}

// GetOrderLocationHistory - Get location trail for specific order
// GET /api/orders/{order_id}/location-history
func (h *TrackingHandler) GetOrderLocationHistory(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	// Parse order ID
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["order_id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Verify user has access to this order
	order, err := h.App.Deps.Orders.GetByID(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusNotFound, "Order not found", err)
		return
	}

	// Authorization check
	canView := false
	switch user.UserType {
	case models.UserTypeAdmin:
		canView = true
	case models.UserTypeCustomer:
		canView = order.CustomerID == user.UserID
	case models.UserTypeDriver:
		driver, _ := h.App.Deps.Users.GetDriverByUserID(user.UserID)
		canView = driver != nil && order.DriverID != nil && *order.DriverID == driver.ID
	}

	if !canView {
		sendError(w, http.StatusForbidden, "Access denied")
		return
	}

	// Fetch location history
	history, err := h.App.Deps.Tracking.GetLocationHistoryByOrder(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve location history", err)
		return
	}

	// Fetch geofence events
	events, err := h.App.Deps.Tracking.GetGeofenceEventsByOrder(orderID)
	if err != nil {
		log.Printf("[WARNING] Failed to retrieve geofence events: %v", err)
		events = []models.GeofenceEvent{}
	}

	// Build response
	var points []models.LocationHistoryPoint
	for _, h := range history {
		points = append(points, models.LocationHistoryPoint{
			Latitude:   h.Latitude,
			Longitude:  h.Longitude,
			SpeedMps:   h.SpeedMps,
			Heading:    h.HeadingDegrees,
			RecordedAt: h.RecordedAt,
			EventType:  h.EventType,
		})
	}

	var driverName string
	if order.DriverID != nil {
		driver, _ := h.App.Deps.Users.GetDriverByID(*order.DriverID)
		if driver != nil {
			driverName = driver.FullName
		}
	}

	response := models.LocationHistoryResponse{
		OrderID:    orderID,
		DriverID:   *order.DriverID,
		DriverName: driverName,
		StartTime:  points[0].RecordedAt,
		Points:     points,
		Events:     events,
	}

	sendSuccess(w, http.StatusOK, "Location history retrieved successfully", response)
}

// StartTracking - Driver starts tracking session
// POST /api/driver/tracking/start
func (h *TrackingHandler) StartTracking(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	if user.UserType != models.UserTypeDriver {
		sendError(w, http.StatusForbidden, "Only drivers can start tracking")
		return
	}

	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve driver", err)
		return
	}

	// Parse request
	var req models.StartTrackingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Check for existing active session
	existingSession, _ := h.App.Deps.Tracking.GetActiveSession(driver.ID)
	if existingSession != nil {
		sendError(w, http.StatusConflict, "Tracking session already active")
		return
	}

	// Create new session
	session := &models.TrackingSession{
		DriverID: driver.ID,
		OrderID:  req.OrderID,
		Status:   "active",
	}

	if err := h.App.Deps.Tracking.CreateTrackingSession(session); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to start tracking session", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Tracking session started", session)
}

// StopTracking - Driver stops tracking session
// POST /api/driver/tracking/stop
func (h *TrackingHandler) StopTracking(w http.ResponseWriter, r *http.Request) {
	user := middleware.MustGetUserFromContext(r.Context())

	if user.UserType != models.UserTypeDriver {
		sendError(w, http.StatusForbidden, "Only drivers can stop tracking")
		return
	}

	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve driver", err)
		return
	}

	// Get active session
	session, err := h.App.Deps.Tracking.GetActiveSession(driver.ID)
	if err != nil {
		sendError(w, http.StatusNotFound, "No active tracking session")
		return
	}

	// Get current location for end position
	location, _ := h.App.Deps.Tracking.GetDriverLocation(driver.ID)

	var endLat, endLng float64
	if location != nil {
		endLat = location.Latitude
		endLng = location.Longitude
	}

	// Calculate duration
	duration := int(time.Since(session.StartedAt).Seconds())

	// End session
	if err := h.App.Deps.Tracking.EndTrackingSession(session.ID, endLat, endLng, 0, duration); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to end tracking session", err)
		return
	}

	// Update driver status to offline
	if err := h.App.Deps.Tracking.UpdateDriverStatus(driver.ID, models.DriverLocationStatusOffline); err != nil {
		log.Printf("[WARNING] Failed to update driver status: %v", err)
	}

	sendSuccess(w, http.StatusOK, "Tracking session stopped", map[string]interface{}{
		"session_id": session.ID,
		"duration":   duration,
	})
}
```

### Step 4.2: Register Routes

**File:** `backend/main.go` (add to existing routes)

```go
// In setupRoutes() function, add tracking routes:

func setupRoutes(r *mux.Router, h *handlers.Handler, geofencingService *services.GeofencingService) {
	// ... existing routes ...

	// Tracking routes
	trackingHandler := handlers.NewTrackingHandler(h, geofencingService)

	// Driver endpoints (protected)
	driverRouter := r.PathPrefix("/api/driver").Subrouter()
	driverRouter.Use(middleware.AuthMiddleware)
	driverRouter.HandleFunc("/location", trackingHandler.UpdateLocation).Methods("POST")
	driverRouter.HandleFunc("/tracking/start", trackingHandler.StartTracking).Methods("POST")
	driverRouter.HandleFunc("/tracking/stop", trackingHandler.StopTracking).Methods("POST")

	// Admin endpoints (protected)
	adminRouter := r.PathPrefix("/api/admin/tracking").Subrouter()
	adminRouter.Use(middleware.AuthMiddleware)
	adminRouter.HandleFunc("/active-drivers", trackingHandler.GetActiveDrivers).Methods("GET")

	// Order tracking (protected)
	r.HandleFunc("/api/orders/{order_id}/location-history", middleware.AuthMiddleware(trackingHandler.GetOrderLocationHistory)).Methods("GET")
}
```

**Testing:**
```bash
# Test location update
curl -X POST http://localhost:8080/api/driver/location \
  -H "Authorization: Bearer $DRIVER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy_meters": 10.5,
    "heading_degrees": 90,
    "speed_mps": 5.2,
    "location_timestamp": "2025-01-15T10:30:00Z",
    "battery_level": 85
  }'

# Test get active drivers
curl -X GET http://localhost:8080/api/admin/tracking/active-drivers \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## Phase 5: Integration and Testing (Day 10-11)

### Step 5.1: Update Dependencies

**File:** `backend/config/dependencies.go`

```go
type Dependencies struct {
	// ... existing repos ...
	Tracking repositories.TrackingRepository
}

func InitDependencies(db *sqlx.DB) *Dependencies {
	return &Dependencies{
		// ... existing ...
		Tracking: repositories.NewTrackingRepository(db),
	}
}
```

### Step 5.2: Initialize Services

**File:** `backend/main.go` (update main function)

```go
func main() {
	// ... existing setup ...

	// Initialize geofencing service
	restaurantRadius := config.GetEnvInt("GEOFENCE_RESTAURANT_RADIUS", 100)
	customerRadius := config.GetEnvInt("GEOFENCE_CUSTOMER_RADIUS", 50)

	geofencingService := services.NewGeofencingService(
		deps.Tracking,
		deps.Restaurants,
		deps.Addresses,
		deps.Orders,
		restaurantRadius,
		customerRadius,
	)

	// Setup routes with new services
	setupRoutes(router, handler, geofencingService)

	// ... start server ...
}
```

### Step 5.3: Create Test Suite

**File:** `backend/handlers/tracking_test.go`

```go
package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"delivery_app/backend/models"
)

func TestUpdateLocation(t *testing.T) {
	// Setup test database and handler
	// Create test driver user
	// Send location update request
	// Verify location saved in database
	// Verify response is 200 OK
}

func TestGetActiveDrivers(t *testing.T) {
	// Setup test database
	// Create multiple drivers with locations
	// Make request as admin
	// Verify all active drivers returned
}

func TestGeofenceArrival(t *testing.T) {
	// Create order with restaurant and delivery address
	// Assign driver to order
	// Send location update near restaurant
	// Verify geofence event created
	// Verify order status updated
}
```

**Run Tests:**
```bash
cd backend
go test ./... -v -cover
```

---

## Deployment Checklist

- [ ] Run migration `006_add_driver_location_tracking.sql` on production database
- [ ] Add environment variables to production `.env`:
  - `GEOFENCE_RESTAURANT_RADIUS=100`
  - `GEOFENCE_CUSTOMER_RADIUS=50`
- [ ] Install new Go dependencies: `go mod tidy`
- [ ] Build backend: `go build -o delivery_app main.go middleware.go`
- [ ] Set up monitoring for:
  - Location update rate
  - Geofence event rate
  - API latency
  - `/api/admin/tracking/active-drivers` response time
- [ ] Create database archival cron job: `SELECT archive_old_location_history(90);`

---

## API Endpoints Summary

### Driver Endpoints
```
POST   /api/driver/location              # Update current location
POST   /api/driver/tracking/start        # Start tracking session
POST   /api/driver/tracking/stop         # Stop tracking session
```

### Admin Endpoints
```
GET    /api/admin/tracking/active-drivers    # Get all active drivers
```

### Order Tracking
```
GET    /api/orders/{order_id}/location-history    # Get delivery trail
```

---

## Performance Considerations

1. **Database Indexing**: All critical queries use composite indexes
2. **Location History Retention**: Automatic cleanup after 90 days
3. **HTTP Polling**: Admin dashboard polls `/api/admin/tracking/active-drivers` every 10 seconds
4. **Rate Limiting**: Implement rate limiting on location update endpoint (1 req/5s per driver)
5. **Caching**: Consider caching active driver list with 10-second TTL to reduce database load

---

## Security Notes

1. **Authorization**: JWT middleware enforces driver can only update their own location
2. **Input Validation**: Coordinate bounds and timestamp format validation
3. **Privacy**: Customer location privacy maintained (no detailed coordinates exposed to drivers)
4. **Rate Limiting**: Prevent location update spam and API abuse
5. **CORS**: Configure proper CORS policy for frontend access

---

## Next Steps

After backend is complete:
1. Update OpenAPI specification in `backend/openapi.yaml`
2. Generate API documentation
3. Coordinate with frontend team on polling intervals and response formats
4. Set up monitoring dashboards
5. Load test with 50+ concurrent drivers
