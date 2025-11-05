package utils

import (
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"time"
)

// IsRestaurantOpen checks if a restaurant is currently open based on hours and timezone
// Returns true if the restaurant is open at the current moment, false otherwise
// If hours_of_operation is nil or empty, defaults to treating restaurant as always open
func IsRestaurantOpen(hoursJSON *string, timezone string) (bool, error) {
	// If no hours configured, treat as always open (allows new restaurants to be visible)
	if hoursJSON == nil || *hoursJSON == "" {
		return true, nil
	}

	// Get current time in restaurant's timezone
	currentTime, err := GetCurrentTimeInTimezone(timezone)
	if err != nil {
		// If timezone is invalid, log error but default to UTC and continue
		currentTime, _ = GetCurrentTimeInTimezone("UTC")
	}

	// Parse hours of operation
	hours, err := ParseHoursOfOperation(*hoursJSON)
	if err != nil {
		// If hours format is invalid, log error and default to open
		// This prevents restaurants from being hidden due to malformed data
		return true, fmt.Errorf("invalid hours format, defaulting to open: %w", err)
	}

	// Get schedule for current day
	schedule, err := GetCurrentDaySchedule(hours, currentTime)
	if err != nil {
		return false, err
	}

	// If the restaurant is closed for the day, return false
	if schedule.Closed {
		return false, nil
	}

	// Check if current time falls within open hours
	isOpen, err := IsTimeInRange(currentTime, schedule.Open, schedule.Close)
	if err != nil {
		// If time parsing fails, default to open to avoid hiding restaurant
		return true, fmt.Errorf("failed to check time range, defaulting to open: %w", err)
	}

	return isOpen, nil
}

// ParseHoursOfOperation parses the JSON string into a structured HoursOfOperation object
func ParseHoursOfOperation(hoursJSON string) (*models.HoursOfOperation, error) {
	if hoursJSON == "" {
		return nil, fmt.Errorf("hours JSON is empty")
	}

	var hours models.HoursOfOperation
	err := json.Unmarshal([]byte(hoursJSON), &hours)
	if err != nil {
		return nil, fmt.Errorf("failed to parse hours JSON: %w", err)
	}

	return &hours, nil
}

// GetCurrentDaySchedule returns the schedule for the current day based on the current time
func GetCurrentDaySchedule(hours *models.HoursOfOperation, currentTime time.Time) (*models.DaySchedule, error) {
	if hours == nil {
		return nil, fmt.Errorf("hours is nil")
	}

	// Get the weekday name
	weekday := currentTime.Weekday().String()

	// Map weekday to schedule
	var schedule models.DaySchedule
	switch weekday {
	case "Monday":
		schedule = hours.Monday
	case "Tuesday":
		schedule = hours.Tuesday
	case "Wednesday":
		schedule = hours.Wednesday
	case "Thursday":
		schedule = hours.Thursday
	case "Friday":
		schedule = hours.Friday
	case "Saturday":
		schedule = hours.Saturday
	case "Sunday":
		schedule = hours.Sunday
	default:
		return nil, fmt.Errorf("invalid weekday: %s", weekday)
	}

	return &schedule, nil
}

// IsTimeInRange checks if the current time falls within the open and close times
// Handles midnight crossover (e.g., open 22:00, close 02:00)
// Times are expected in "HH:MM" format (24-hour)
func IsTimeInRange(currentTime time.Time, openTime, closeTime string) (bool, error) {
	// Parse open and close times
	openHour, openMinute, err := parseTimeString(openTime)
	if err != nil {
		return false, fmt.Errorf("failed to parse open time '%s': %w", openTime, err)
	}

	closeHour, closeMinute, err := parseTimeString(closeTime)
	if err != nil {
		return false, fmt.Errorf("failed to parse close time '%s': %w", closeTime, err)
	}

	// Create time objects for open and close using current date
	// This allows for proper time comparison
	year, month, day := currentTime.Date()
	location := currentTime.Location()

	openTimeObj := time.Date(year, month, day, openHour, openMinute, 0, 0, location)
	closeTimeObj := time.Date(year, month, day, closeHour, closeMinute, 0, 0, location)

	// Check if close time is before open time (midnight crossover)
	if closeTimeObj.Before(openTimeObj) {
		// Midnight crossover case: open 22:00, close 02:00
		// Restaurant is open if current time is:
		// - After or equal to open time (today) OR
		// - Before close time (assumed to be from previous day's opening)

		// Adjust close time to next day
		closeTimeObj = closeTimeObj.Add(24 * time.Hour)

		// If current time is before the original close time, we need to check
		// if it's from the previous day's opening
		if currentTime.Hour() < closeHour || (currentTime.Hour() == closeHour && currentTime.Minute() < closeMinute) {
			// Current time is early in the day (before close time)
			// Check if we're within the late-night window from previous day
			return currentTime.Before(closeTimeObj) && currentTime.After(openTimeObj.Add(-24*time.Hour)), nil
		}

		// Current time is later in the day (after or equal to open time)
		return currentTime.After(openTimeObj) || currentTime.Equal(openTimeObj), nil
	}

	// Normal case: open 09:00, close 21:00
	// Restaurant is open if current time is >= open time AND < close time
	return (currentTime.After(openTimeObj) || currentTime.Equal(openTimeObj)) && currentTime.Before(closeTimeObj), nil
}

// parseTimeString parses a time string in "HH:MM" format and returns hour and minute
func parseTimeString(timeStr string) (hour, minute int, err error) {
	if timeStr == "" {
		return 0, 0, fmt.Errorf("time string is empty")
	}

	// Parse using time.Parse with a reference date
	t, err := time.Parse("15:04", timeStr)
	if err != nil {
		return 0, 0, fmt.Errorf("invalid time format (expected HH:MM): %w", err)
	}

	return t.Hour(), t.Minute(), nil
}

// GetDayName returns the English name of a weekday for a given time
func GetDayName(t time.Time) string {
	return t.Weekday().String()
}

// FormatDaySchedule formats a DaySchedule as a human-readable string
func FormatDaySchedule(schedule models.DaySchedule) string {
	if schedule.Closed {
		return "Closed"
	}
	return fmt.Sprintf("%s - %s", schedule.Open, schedule.Close)
}

// ValidateHoursOfOperation checks if the hours of operation JSON is valid
// Returns nil if valid, error describing the issue if invalid
func ValidateHoursOfOperation(hoursJSON string) error {
	if hoursJSON == "" {
		return fmt.Errorf("hours JSON is empty")
	}

	hours, err := ParseHoursOfOperation(hoursJSON)
	if err != nil {
		return err
	}

	// Validate each day's schedule
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
			// Validate open and close time formats
			if _, _, err := parseTimeString(day.schedule.Open); err != nil {
				return fmt.Errorf("%s open time is invalid: %w", day.name, err)
			}
			if _, _, err := parseTimeString(day.schedule.Close); err != nil {
				return fmt.Errorf("%s close time is invalid: %w", day.name, err)
			}
		}
	}

	return nil
}
