package models

// DaySchedule represents operating hours for a single day
type DaySchedule struct {
	Open   string `json:"open"`   // "HH:MM" format (24-hour)
	Close  string `json:"close"`  // "HH:MM" format (24-hour)
	Closed bool   `json:"closed"` // If true, open/close times are ignored
}

// HoursOfOperation represents weekly operating hours
type HoursOfOperation struct {
	Monday    DaySchedule `json:"monday"`
	Tuesday   DaySchedule `json:"tuesday"`
	Wednesday DaySchedule `json:"wednesday"`
	Thursday  DaySchedule `json:"thursday"`
	Friday    DaySchedule `json:"friday"`
	Saturday  DaySchedule `json:"saturday"`
	Sunday    DaySchedule `json:"sunday"`
}

// VendorSettings represents vendor restaurant settings for a specific restaurant
type VendorSettings struct {
	RestaurantID         int               `json:"restaurant_id"`
	RestaurantName       string            `json:"restaurant_name"`
	AveragePrepTimeMin   int               `json:"average_prep_time_minutes"`
	HoursOfOperation     *HoursOfOperation `json:"hours_of_operation,omitempty"`
}

// UpdateVendorSettingsRequest represents the request to update vendor restaurant settings
type UpdateVendorSettingsRequest struct {
	AveragePrepTimeMin *int               `json:"average_prep_time_minutes,omitempty"`
	HoursOfOperation   *HoursOfOperation  `json:"hours_of_operation,omitempty"`
}

// UpdatePrepTimeRequest represents the request to update only prep time
type UpdatePrepTimeRequest struct {
	AveragePrepTimeMin int `json:"average_prep_time_minutes" validate:"required,min=1,max=300"`
}

// ConfirmOrderRequest represents the request to confirm an order with optional prep time override
type ConfirmOrderRequest struct {
	EstimatedPrepTimeMin *int `json:"estimated_prep_time_minutes,omitempty" validate:"omitempty,min=1,max=300"`
}
