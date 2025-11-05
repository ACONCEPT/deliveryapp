package base

import "fmt"

// AddressFields provides standard address fields that can be embedded
// in any model requiring address information
type AddressFields struct {
	AddressLine1 *string `json:"address_line1,omitempty" db:"address_line1"`
	AddressLine2 *string `json:"address_line2,omitempty" db:"address_line2"`
	City         *string `json:"city,omitempty" db:"city"`
	State        *string `json:"state,omitempty" db:"state"`
	PostalCode   *string `json:"postal_code,omitempty" db:"postal_code"`
	Country      *string `json:"country,omitempty" db:"country"`
}

// GeoLocation provides latitude and longitude coordinates
type GeoLocation struct {
	Latitude  *float64 `json:"latitude,omitempty" db:"latitude"`
	Longitude *float64 `json:"longitude,omitempty" db:"longitude"`
}

// FullAddress combines address fields with geolocation
type FullAddress struct {
	AddressFields
	GeoLocation
}

// FormatShort returns a short formatted address (e.g., "City, State")
func (a *AddressFields) FormatShort() string {
	if a.City != nil && a.State != nil {
		return fmt.Sprintf("%s, %s", *a.City, *a.State)
	}
	if a.City != nil {
		return *a.City
	}
	return ""
}

// FormatFull returns a full formatted address
func (a *AddressFields) FormatFull() string {
	parts := []string{}

	if a.AddressLine1 != nil && *a.AddressLine1 != "" {
		parts = append(parts, *a.AddressLine1)
	}
	if a.AddressLine2 != nil && *a.AddressLine2 != "" {
		parts = append(parts, *a.AddressLine2)
	}
	if a.City != nil && *a.City != "" {
		cityState := *a.City
		if a.State != nil && *a.State != "" {
			cityState = fmt.Sprintf("%s, %s", cityState, *a.State)
		}
		if a.PostalCode != nil && *a.PostalCode != "" {
			cityState = fmt.Sprintf("%s %s", cityState, *a.PostalCode)
		}
		parts = append(parts, cityState)
	}
	if a.Country != nil && *a.Country != "" {
		parts = append(parts, *a.Country)
	}

	result := ""
	for i, part := range parts {
		if i > 0 {
			result += ", "
		}
		result += part
	}
	return result
}

// IsValid checks if the address has minimum required fields
func (a *AddressFields) IsValid() bool {
	return a.AddressLine1 != nil && *a.AddressLine1 != "" &&
		a.City != nil && *a.City != "" &&
		a.State != nil && *a.State != ""
}

// HasCoordinates checks if geolocation data is present
func (g *GeoLocation) HasCoordinates() bool {
	return g.Latitude != nil && g.Longitude != nil
}

// IsValid checks if coordinates are within valid ranges
func (g *GeoLocation) IsValid() bool {
	if !g.HasCoordinates() {
		return false
	}
	// Valid latitude: -90 to 90
	// Valid longitude: -180 to 180
	return *g.Latitude >= -90 && *g.Latitude <= 90 &&
		*g.Longitude >= -180 && *g.Longitude <= 180
}
