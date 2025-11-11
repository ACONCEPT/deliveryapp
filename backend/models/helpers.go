package models

// ToNullString returns the string value or nil for SQL queries
func ToNullString(ns NullString) interface{} {
	if ns.Valid {
		return ns.String
	}
	return nil
}

// ToNullInt64 returns the int64 value or nil for SQL queries
func ToNullInt64(ni NullInt64) interface{} {
	if ni.Valid {
		return ni.Int64
	}
	return nil
}

// ToNullTime returns the time value or nil for SQL queries
func ToNullTime(nt NullTime) interface{} {
	if nt.Valid {
		return nt.Time
	}
	return nil
}
