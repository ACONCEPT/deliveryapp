# Restaurant Hours Filtering - Quick Reference

## Quick Test

```bash
# 1. Start backend
cd backend && ./delivery_app

# 2. Login as customer
TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "customer1", "password": "password123"}' | jq -r '.token')

# 3. List restaurants (only open ones)
curl -X GET http://localhost:8080/api/restaurants \
  -H "Authorization: Bearer $TOKEN" | jq '.restaurants[] | {id, name, timezone, hours_of_operation}'
```

## Key Functions

### Check if Restaurant is Open
```go
import "delivery_app/backend/utils"

isOpen, err := utils.IsRestaurantOpen(hoursJSON, timezone)
// Returns: true if open now, false if closed
// hoursJSON: *string (JSONB hours), timezone: string (IANA identifier)
```

### Parse Hours JSON
```go
hours, err := utils.ParseHoursOfOperation(hoursJSON)
// Returns: *models.HoursOfOperation struct
```

### Validate Hours Format
```go
err := utils.ValidateHoursOfOperation(hoursJSON)
// Returns: nil if valid, error if invalid
```

## Hours JSON Format

```json
{
  "monday": {"open": "09:00", "close": "21:00", "closed": false},
  "tuesday": {"open": "09:00", "close": "21:00", "closed": false},
  "wednesday": {"open": "09:00", "close": "21:00", "closed": false},
  "thursday": {"open": "09:00", "close": "21:00", "closed": false},
  "friday": {"open": "09:00", "close": "22:00", "closed": false},
  "saturday": {"open": "10:00", "close": "22:00", "closed": false},
  "sunday": {"open": "10:00", "close": "20:00", "closed": true}
}
```

**Rules:**
- Times in "HH:MM" format (24-hour)
- `closed: true` means closed all day (open/close ignored)
- Supports midnight crossover (e.g., "22:00" to "02:00")

## User Type Behavior

| User       | Hours Filter? | Sees Closed? |
|------------|---------------|--------------|
| Customer   | Yes           | No           |
| Driver     | Yes           | No           |
| Vendor     | No            | Yes          |
| Admin      | No            | Yes          |

## Default Behaviors

| Scenario              | Behavior                    |
|-----------------------|-----------------------------|
| No hours configured   | Treated as always open      |
| Invalid hours JSON    | Treated as always open      |
| Invalid timezone      | Falls back to UTC           |
| Midnight crossover    | Correctly handles 22:00-02:00 |
| Closed day flag       | Returns closed immediately  |

## Testing

```bash
# Run unit tests
cd backend
go test -v ./utils

# Run integration tests
cd backend
./test_hours_filtering.sh

# Check logs
grep '[Hours Filter]' backend.log
```

## Common Examples

### Always Open (24/7)
```json
{
  "monday": {"open": "00:00", "close": "23:59", "closed": false},
  ...all days same...
}
```

### Closed on Sundays
```json
{
  "sunday": {"open": "00:00", "close": "00:00", "closed": true}
}
```

### Late Night Hours (Midnight Crossover)
```json
{
  "friday": {"open": "18:00", "close": "02:00", "closed": false},
  "saturday": {"open": "18:00", "close": "02:00", "closed": false}
}
```
*Open from 6 PM to 2 AM*

### Lunch Only
```json
{
  "monday": {"open": "11:00", "close": "14:00", "closed": false}
}
```

## Debugging

### Check Restaurant Configuration
```sql
SELECT id, name, timezone, hours_of_operation, is_active, approval_status
FROM restaurants
WHERE id = 1;
```

### Check Current Status
```bash
# In Go code (temporary debugging)
log.Printf("[DEBUG] Restaurant %d: tz=%s, hours=%v",
    restaurant.ID, restaurant.Timezone, restaurant.HoursOfOperation)

isOpen, err := utils.IsRestaurantOpen(
    restaurant.HoursOfOperation,
    restaurant.Timezone,
)
log.Printf("[DEBUG] isOpen=%v, err=%v", isOpen, err)
```

### Common Issues

**Restaurant not showing:**
1. Check approval_status = 'approved'
2. Check is_active = true
3. Check hours_of_operation format
4. Check timezone is valid IANA identifier
5. Check current time in restaurant's timezone

**Restaurant showing when closed:**
1. Verify hours JSON format
2. Check for typos in day names (must be lowercase)
3. Verify timezone matches restaurant location
4. Check for cached data

## Performance

- **Per Restaurant Check:** ~24 microseconds
- **100 Restaurants:** ~2.4 ms
- **1000 Restaurants:** ~24 ms

**Optimization if needed:**
```go
// Add caching (future enhancement)
const cacheKey = fmt.Sprintf("restaurant:%d:is_open", restaurantID)
if cached := redis.Get(cacheKey); cached != nil {
    return cached.(bool), nil
}
// ... check hours ...
redis.Set(cacheKey, isOpen, 60*time.Second) // Cache for 1 minute
```

## Related Files

- **Hours Logic:** `backend/utils/hours.go`
- **Unit Tests:** `backend/utils/hours_test.go`
- **Handler:** `backend/handlers/restaurant.go` (lines 118-150)
- **Models:** `backend/models/vendor_settings.go`
- **Timezone Utils:** `backend/utils/timezone.go`
- **API Docs:** `backend/openapi/paths/restaurants.yaml`
- **Full Documentation:** `backend/HOURS_FILTERING_IMPLEMENTATION.md`

## Quick Setup for New Restaurant

```bash
# 1. Create restaurant (vendor login required)
curl -X POST http://localhost:8080/api/vendor/restaurants \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Restaurant",
    "timezone": "America/New_York"
  }'

# 2. Set hours via vendor settings endpoint
curl -X PUT http://localhost:8080/api/vendor/restaurant/1/settings \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hours_of_operation": {
      "monday": {"open": "09:00", "close": "21:00", "closed": false},
      "tuesday": {"open": "09:00", "close": "21:00", "closed": false},
      "wednesday": {"open": "09:00", "close": "21:00", "closed": false},
      "thursday": {"open": "09:00", "close": "21:00", "closed": false},
      "friday": {"open": "09:00", "close": "22:00", "closed": false},
      "saturday": {"open": "10:00", "close": "22:00", "closed": false},
      "sunday": {"open": "10:00", "close": "20:00", "closed": true}
    }
  }'

# 3. Admin approval required before customers can see it
curl -X POST http://localhost:8080/api/admin/restaurants/1/approve \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Timezones Reference

Common IANA timezone identifiers:

**US:**
- `America/New_York` - Eastern Time
- `America/Chicago` - Central Time
- `America/Denver` - Mountain Time
- `America/Los_Angeles` - Pacific Time
- `America/Phoenix` - Arizona (no DST)
- `Pacific/Honolulu` - Hawaii

**International:**
- `Europe/London` - UK
- `Europe/Paris` - France/Spain/Italy
- `Asia/Tokyo` - Japan
- `Asia/Shanghai` - China
- `Australia/Sydney` - Australia East

Full list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
