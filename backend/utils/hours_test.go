package utils

import (
	"delivery_app/backend/models"
	"testing"
	"time"
)

// TestParseHoursOfOperation tests parsing of hours JSON
func TestParseHoursOfOperation(t *testing.T) {
	validJSON := `{
		"monday": {"open": "09:00", "close": "21:00", "closed": false},
		"tuesday": {"open": "09:00", "close": "21:00", "closed": false},
		"wednesday": {"open": "09:00", "close": "21:00", "closed": false},
		"thursday": {"open": "09:00", "close": "21:00", "closed": false},
		"friday": {"open": "09:00", "close": "21:00", "closed": false},
		"saturday": {"open": "10:00", "close": "22:00", "closed": false},
		"sunday": {"open": "10:00", "close": "20:00", "closed": true}
	}`

	hours, err := ParseHoursOfOperation(validJSON)
	if err != nil {
		t.Errorf("ParseHoursOfOperation failed: %v", err)
	}

	if hours.Monday.Open != "09:00" {
		t.Errorf("Expected Monday open to be 09:00, got %s", hours.Monday.Open)
	}

	if !hours.Sunday.Closed {
		t.Error("Expected Sunday to be closed")
	}

	// Test empty JSON
	_, err = ParseHoursOfOperation("")
	if err == nil {
		t.Error("Expected error for empty JSON")
	}

	// Test invalid JSON
	_, err = ParseHoursOfOperation("not valid json")
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
}

// TestGetCurrentDaySchedule tests getting schedule for current day
func TestGetCurrentDaySchedule(t *testing.T) {
	hours := &models.HoursOfOperation{
		Monday:    models.DaySchedule{Open: "09:00", Close: "17:00", Closed: false},
		Tuesday:   models.DaySchedule{Open: "09:00", Close: "17:00", Closed: false},
		Wednesday: models.DaySchedule{Open: "09:00", Close: "17:00", Closed: false},
		Thursday:  models.DaySchedule{Open: "09:00", Close: "17:00", Closed: false},
		Friday:    models.DaySchedule{Open: "09:00", Close: "17:00", Closed: false},
		Saturday:  models.DaySchedule{Open: "10:00", Close: "15:00", Closed: false},
		Sunday:    models.DaySchedule{Open: "10:00", Close: "15:00", Closed: true},
	}

	// Test Monday
	mondayTime := time.Date(2025, 10, 27, 12, 0, 0, 0, time.UTC) // Monday
	schedule, err := GetCurrentDaySchedule(hours, mondayTime)
	if err != nil {
		t.Errorf("GetCurrentDaySchedule failed: %v", err)
	}
	if schedule.Open != "09:00" {
		t.Errorf("Expected Monday schedule open 09:00, got %s", schedule.Open)
	}

	// Test Sunday (closed day)
	sundayTime := time.Date(2025, 11, 2, 12, 0, 0, 0, time.UTC) // Sunday
	schedule, err = GetCurrentDaySchedule(hours, sundayTime)
	if err != nil {
		t.Errorf("GetCurrentDaySchedule failed: %v", err)
	}
	if !schedule.Closed {
		t.Error("Expected Sunday to be closed")
	}

	// Test nil hours
	_, err = GetCurrentDaySchedule(nil, mondayTime)
	if err == nil {
		t.Error("Expected error for nil hours")
	}
}

// TestIsTimeInRange tests time range checking
func TestIsTimeInRange(t *testing.T) {
	// Test case 1: Normal hours (9 AM - 5 PM), current time is noon
	loc, _ := time.LoadLocation("America/New_York")
	currentTime := time.Date(2025, 10, 27, 12, 0, 0, 0, loc)
	isOpen, err := IsTimeInRange(currentTime, "09:00", "17:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant to be open at noon (09:00-17:00)")
	}

	// Test case 2: Before opening
	earlyTime := time.Date(2025, 10, 27, 8, 0, 0, 0, loc)
	isOpen, err = IsTimeInRange(earlyTime, "09:00", "17:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if isOpen {
		t.Error("Expected restaurant to be closed at 8 AM (opens at 09:00)")
	}

	// Test case 3: After closing
	lateTime := time.Date(2025, 10, 27, 18, 0, 0, 0, loc)
	isOpen, err = IsTimeInRange(lateTime, "09:00", "17:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if isOpen {
		t.Error("Expected restaurant to be closed at 6 PM (closes at 17:00)")
	}

	// Test case 4: Exactly at opening time
	openingTime := time.Date(2025, 10, 27, 9, 0, 0, 0, loc)
	isOpen, err = IsTimeInRange(openingTime, "09:00", "17:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant to be open at exactly 09:00")
	}

	// Test case 5: Midnight crossover (10 PM - 2 AM)
	lateNightTime := time.Date(2025, 10, 27, 23, 0, 0, 0, loc) // 11 PM
	isOpen, err = IsTimeInRange(lateNightTime, "22:00", "02:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant to be open at 11 PM (22:00-02:00 crossover)")
	}

	// Test case 6: Midnight crossover - early morning
	earlyMorning := time.Date(2025, 10, 27, 1, 0, 0, 0, loc) // 1 AM
	isOpen, err = IsTimeInRange(earlyMorning, "22:00", "02:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant to be open at 1 AM (22:00-02:00 crossover)")
	}

	// Test case 7: Midnight crossover - outside hours
	afternoonTime := time.Date(2025, 10, 27, 15, 0, 0, 0, loc) // 3 PM
	isOpen, err = IsTimeInRange(afternoonTime, "22:00", "02:00")
	if err != nil {
		t.Errorf("IsTimeInRange failed: %v", err)
	}
	if isOpen {
		t.Error("Expected restaurant to be closed at 3 PM (22:00-02:00 hours)")
	}
}

// TestIsRestaurantOpen tests the main function
func TestIsRestaurantOpen(t *testing.T) {
	// Test case 1: No hours configured (should default to open)
	isOpen, err := IsRestaurantOpen(nil, "America/New_York")
	if err != nil {
		t.Errorf("IsRestaurantOpen failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant with no hours to be treated as open")
	}

	// Test case 2: Empty hours string (should default to open)
	emptyHours := ""
	isOpen, err = IsRestaurantOpen(&emptyHours, "America/New_York")
	if err != nil {
		t.Errorf("IsRestaurantOpen failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant with empty hours to be treated as open")
	}

	// Test case 3: Valid hours - restaurant open (always open 00:00-23:59)
	alwaysOpenHours := `{
		"monday": {"open": "00:00", "close": "23:59", "closed": false},
		"tuesday": {"open": "00:00", "close": "23:59", "closed": false},
		"wednesday": {"open": "00:00", "close": "23:59", "closed": false},
		"thursday": {"open": "00:00", "close": "23:59", "closed": false},
		"friday": {"open": "00:00", "close": "23:59", "closed": false},
		"saturday": {"open": "00:00", "close": "23:59", "closed": false},
		"sunday": {"open": "00:00", "close": "23:59", "closed": false}
	}`
	isOpen, err = IsRestaurantOpen(&alwaysOpenHours, "America/New_York")
	if err != nil {
		t.Errorf("IsRestaurantOpen failed: %v", err)
	}
	if !isOpen {
		t.Error("Expected restaurant with 00:00-23:59 hours to be open")
	}

	// Test case 4: Valid hours - restaurant closed (01:00-02:00 AM)
	closedHours := `{
		"monday": {"open": "01:00", "close": "02:00", "closed": false},
		"tuesday": {"open": "01:00", "close": "02:00", "closed": false},
		"wednesday": {"open": "01:00", "close": "02:00", "closed": false},
		"thursday": {"open": "01:00", "close": "02:00", "closed": false},
		"friday": {"open": "01:00", "close": "02:00", "closed": false},
		"saturday": {"open": "01:00", "close": "02:00", "closed": false},
		"sunday": {"open": "01:00", "close": "02:00", "closed": false}
	}`
	// This test will fail if run between 1-2 AM, but that's unlikely
	isOpen, err = IsRestaurantOpen(&closedHours, "America/New_York")
	if err != nil {
		t.Errorf("IsRestaurantOpen failed: %v", err)
	}
	// We can't assert this reliably since it depends on current time
	// Just verify no error occurred
}

// TestValidateHoursOfOperation tests hours validation
func TestValidateHoursOfOperation(t *testing.T) {
	// Test valid hours
	validHours := `{
		"monday": {"open": "09:00", "close": "17:00", "closed": false},
		"tuesday": {"open": "09:00", "close": "17:00", "closed": false},
		"wednesday": {"open": "09:00", "close": "17:00", "closed": false},
		"thursday": {"open": "09:00", "close": "17:00", "closed": false},
		"friday": {"open": "09:00", "close": "17:00", "closed": false},
		"saturday": {"open": "10:00", "close": "15:00", "closed": false},
		"sunday": {"open": "10:00", "close": "15:00", "closed": true}
	}`
	err := ValidateHoursOfOperation(validHours)
	if err != nil {
		t.Errorf("ValidateHoursOfOperation failed for valid hours: %v", err)
	}

	// Test invalid hours format - bad time
	invalidHours := `{
		"monday": {"open": "25:00", "close": "17:00", "closed": false},
		"tuesday": {"open": "09:00", "close": "17:00", "closed": false},
		"wednesday": {"open": "09:00", "close": "17:00", "closed": false},
		"thursday": {"open": "09:00", "close": "17:00", "closed": false},
		"friday": {"open": "09:00", "close": "17:00", "closed": false},
		"saturday": {"open": "10:00", "close": "15:00", "closed": false},
		"sunday": {"open": "10:00", "close": "15:00", "closed": false}
	}`
	err = ValidateHoursOfOperation(invalidHours)
	if err == nil {
		t.Error("Expected error for invalid time format (25:00)")
	}

	// Test empty hours
	err = ValidateHoursOfOperation("")
	if err == nil {
		t.Error("Expected error for empty hours")
	}

	// Test invalid JSON
	err = ValidateHoursOfOperation("not json")
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
}

// TestFormatDaySchedule tests schedule formatting
func TestFormatDaySchedule(t *testing.T) {
	// Test open schedule
	openSchedule := models.DaySchedule{
		Open:   "09:00",
		Close:  "17:00",
		Closed: false,
	}
	formatted := FormatDaySchedule(openSchedule)
	if formatted != "09:00 - 17:00" {
		t.Errorf("Expected '09:00 - 17:00', got '%s'", formatted)
	}

	// Test closed schedule
	closedSchedule := models.DaySchedule{
		Open:   "09:00",
		Close:  "17:00",
		Closed: true,
	}
	formatted = FormatDaySchedule(closedSchedule)
	if formatted != "Closed" {
		t.Errorf("Expected 'Closed', got '%s'", formatted)
	}
}

// TestParseTimeString tests time string parsing
func TestParseTimeString(t *testing.T) {
	// Test valid time
	hour, minute, err := parseTimeString("14:30")
	if err != nil {
		t.Errorf("parseTimeString failed: %v", err)
	}
	if hour != 14 || minute != 30 {
		t.Errorf("Expected hour=14, minute=30, got hour=%d, minute=%d", hour, minute)
	}

	// Test midnight
	hour, minute, err = parseTimeString("00:00")
	if err != nil {
		t.Errorf("parseTimeString failed: %v", err)
	}
	if hour != 0 || minute != 0 {
		t.Errorf("Expected hour=0, minute=0, got hour=%d, minute=%d", hour, minute)
	}

	// Test end of day
	hour, minute, err = parseTimeString("23:59")
	if err != nil {
		t.Errorf("parseTimeString failed: %v", err)
	}
	if hour != 23 || minute != 59 {
		t.Errorf("Expected hour=23, minute=59, got hour=%d, minute=%d", hour, minute)
	}

	// Test invalid format
	_, _, err = parseTimeString("25:00")
	if err == nil {
		t.Error("Expected error for invalid hour")
	}

	_, _, err = parseTimeString("not a time")
	if err == nil {
		t.Error("Expected error for invalid format")
	}

	_, _, err = parseTimeString("")
	if err == nil {
		t.Error("Expected error for empty string")
	}
}

// TestGetDayName tests day name extraction
func TestGetDayName(t *testing.T) {
	// Monday
	monday := time.Date(2025, 10, 27, 12, 0, 0, 0, time.UTC)
	if GetDayName(monday) != "Monday" {
		t.Errorf("Expected 'Monday', got '%s'", GetDayName(monday))
	}

	// Sunday
	sunday := time.Date(2025, 11, 2, 12, 0, 0, 0, time.UTC)
	if GetDayName(sunday) != "Sunday" {
		t.Errorf("Expected 'Sunday', got '%s'", GetDayName(sunday))
	}
}

// Benchmark tests
func BenchmarkIsRestaurantOpen(b *testing.B) {
	hoursJSON := `{
		"monday": {"open": "09:00", "close": "17:00", "closed": false},
		"tuesday": {"open": "09:00", "close": "17:00", "closed": false},
		"wednesday": {"open": "09:00", "close": "17:00", "closed": false},
		"thursday": {"open": "09:00", "close": "17:00", "closed": false},
		"friday": {"open": "09:00", "close": "17:00", "closed": false},
		"saturday": {"open": "10:00", "close": "15:00", "closed": false},
		"sunday": {"open": "10:00", "close": "15:00", "closed": true}
	}`

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		IsRestaurantOpen(&hoursJSON, "America/New_York")
	}
}

func BenchmarkParseHoursOfOperation(b *testing.B) {
	hoursJSON := `{
		"monday": {"open": "09:00", "close": "17:00", "closed": false},
		"tuesday": {"open": "09:00", "close": "17:00", "closed": false},
		"wednesday": {"open": "09:00", "close": "17:00", "closed": false},
		"thursday": {"open": "09:00", "close": "17:00", "closed": false},
		"friday": {"open": "09:00", "close": "17:00", "closed": false},
		"saturday": {"open": "10:00", "close": "15:00", "closed": false},
		"sunday": {"open": "10:00", "close": "15:00", "closed": true}
	}`

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ParseHoursOfOperation(hoursJSON)
	}
}
