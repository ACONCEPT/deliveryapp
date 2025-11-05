package base

import "time"

// Timestamps provides standard created_at and updated_at fields
// that can be embedded in any model requiring audit timestamps
type Timestamps struct {
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// Age returns the duration since the entity was created
func (t *Timestamps) Age() time.Duration {
	return time.Since(t.CreatedAt)
}

// TimeSinceUpdate returns the duration since the entity was last updated
func (t *Timestamps) TimeSinceUpdate() time.Duration {
	return time.Since(t.UpdatedAt)
}

// IsRecent returns true if the entity was created within the specified duration
func (t *Timestamps) IsRecent(duration time.Duration) bool {
	return t.Age() < duration
}

// WasRecentlyUpdated returns true if the entity was updated within the specified duration
func (t *Timestamps) WasRecentlyUpdated(duration time.Duration) bool {
	return t.TimeSinceUpdate() < duration
}
