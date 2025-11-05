package utils

import (
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

// GetRestaurantTimezone fetches the timezone for a restaurant from the database
func GetRestaurantTimezone(restaurantID int, db *sqlx.DB) (string, error) {
	var timezone string
	query := `SELECT timezone FROM restaurants WHERE id = $1`

	err := db.Get(&timezone, query, restaurantID)
	if err != nil {
		return "", fmt.Errorf("failed to get restaurant timezone: %w", err)
	}

	// Validate the timezone is valid
	if err := ValidateTimezone(timezone); err != nil {
		// If invalid, log warning and default to UTC
		return "UTC", fmt.Errorf("restaurant has invalid timezone '%s', defaulting to UTC: %w", timezone, err)
	}

	return timezone, nil
}

// ConvertToRestaurantTime converts a UTC time to the restaurant's local time
func ConvertToRestaurantTime(utcTime time.Time, timezone string) (time.Time, error) {
	// Load the timezone location
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return utcTime, fmt.Errorf("failed to load timezone '%s': %w", timezone, err)
	}

	// Convert UTC time to the target timezone
	return utcTime.In(loc), nil
}

// ConvertFromRestaurantTime converts a restaurant's local time to UTC
func ConvertFromRestaurantTime(localTime time.Time, timezone string) (time.Time, error) {
	// Load the timezone location
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return localTime, fmt.Errorf("failed to load timezone '%s': %w", timezone, err)
	}

	// Ensure the time is interpreted in the restaurant's timezone
	// If it doesn't have timezone info, assign it
	if localTime.Location().String() == "UTC" {
		localTime = time.Date(
			localTime.Year(), localTime.Month(), localTime.Day(),
			localTime.Hour(), localTime.Minute(), localTime.Second(),
			localTime.Nanosecond(), loc,
		)
	}

	// Convert to UTC
	return localTime.UTC(), nil
}

// FormatTimeWithoutTZ formats a time in the restaurant's timezone without timezone suffix
// Returns format: "2006-01-02T15:04:05" (no Z or offset)
func FormatTimeWithoutTZ(t time.Time, timezone string) (string, error) {
	// Convert to restaurant timezone
	localTime, err := ConvertToRestaurantTime(t, timezone)
	if err != nil {
		return "", err
	}

	// Format without timezone indicator
	// Use RFC3339 format but strip the timezone part
	return localTime.Format("2006-01-02T15:04:05"), nil
}

// ValidateTimezone checks if a timezone string is a valid IANA timezone identifier
func ValidateTimezone(timezone string) error {
	if timezone == "" {
		return fmt.Errorf("timezone cannot be empty")
	}

	// Try to load the timezone
	_, err := time.LoadLocation(timezone)
	if err != nil {
		return fmt.Errorf("invalid IANA timezone identifier: %w", err)
	}

	return nil
}

// GetCurrentTimeInTimezone returns the current time in the specified timezone
func GetCurrentTimeInTimezone(timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to load timezone '%s': %w", timezone, err)
	}

	return time.Now().In(loc), nil
}

// ParseTimeInTimezone parses a time string in the context of a specific timezone
// Expects format: "2006-01-02T15:04:05" (without timezone indicator)
func ParseTimeInTimezone(timeStr string, timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to load timezone '%s': %w", timezone, err)
	}

	// Parse the time string in the specified timezone
	t, err := time.ParseInLocation("2006-01-02T15:04:05", timeStr, loc)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to parse time '%s': %w", timeStr, err)
	}

	return t, nil
}

// CommonTimezones provides a list of commonly used IANA timezone identifiers
var CommonTimezones = []string{
	// US Timezones
	"America/New_York",    // Eastern Time
	"America/Chicago",     // Central Time
	"America/Denver",      // Mountain Time
	"America/Los_Angeles", // Pacific Time
	"America/Anchorage",   // Alaska Time
	"America/Phoenix",     // Arizona (no DST)
	"Pacific/Honolulu",    // Hawaii Time

	// Other North American
	"America/Toronto",
	"America/Vancouver",
	"America/Mexico_City",

	// European
	"Europe/London",
	"Europe/Paris",
	"Europe/Berlin",
	"Europe/Madrid",
	"Europe/Rome",
	"Europe/Moscow",

	// Asian
	"Asia/Tokyo",
	"Asia/Shanghai",
	"Asia/Hong_Kong",
	"Asia/Singapore",
	"Asia/Dubai",
	"Asia/Kolkata",

	// Australian
	"Australia/Sydney",
	"Australia/Melbourne",
	"Australia/Perth",

	// UTC
	"UTC",
}

// IsCommonTimezone checks if a timezone is in the common timezones list
func IsCommonTimezone(timezone string) bool {
	for _, tz := range CommonTimezones {
		if tz == timezone {
			return true
		}
	}
	return false
}