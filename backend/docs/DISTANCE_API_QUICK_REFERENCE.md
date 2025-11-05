# Distance API Quick Reference

## Setup (5 minutes)

```bash
# 1. Get Mapbox token
open https://account.mapbox.com/access-tokens/

# 2. Add to .env
echo "MAPBOX_ACCESS_TOKEN=pk.your_token_here" >> backend/.env

# 3. Migrate database
./tools/sh/setup-database.sh

# 4. Start backend
cd backend && go run main.go middleware.go
```

## API Endpoints

| Endpoint | Method | Auth | User Types | Description |
|----------|--------|------|------------|-------------|
| `/api/distance/estimate` | POST | ✓ | All | Calculate distance |
| `/api/distance/history` | GET | ✓ | All | Get request history |
| `/api/admin/distance/usage` | GET | ✓ | Admin | Get usage stats |

## Quick Examples

### Calculate Distance
```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"customer1","password":"password123"}' \
  | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

# 2. Calculate
curl -X POST http://localhost:8080/api/distance/estimate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"address_id":1,"restaurant_id":1}'
```

### Get Usage Stats (Admin)
```bash
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin1","password":"password123"}' \
  | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

curl -X GET http://localhost:8080/api/admin/distance/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Error Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | Success | Distance calculated |
| 400 | Bad Request | Invalid coordinates |
| 401 | Unauthorized | Missing/invalid token |
| 403 | Forbidden | Customer accessing other's address |
| 404 | Not Found | Address/restaurant doesn't exist |
| 429 | Rate Limit | Mapbox quota exceeded |
| 500 | Server Error | Mapbox API failure |

## Common Issues

### "MAPBOX_ACCESS_TOKEN is not set"
```bash
echo "MAPBOX_ACCESS_TOKEN=pk.your_token" >> backend/.env
```

### "Address does not have valid coordinates"
```sql
-- Add coordinates to address
UPDATE customer_addresses
SET latitude = 40.7128, longitude = -74.0060
WHERE id = 1;
```

### Check API Usage
```sql
-- Today's usage
SELECT COUNT(*) FROM distance_requests
WHERE status = 'success' AND DATE(created_at) = CURRENT_DATE;

-- Monthly usage
SELECT COUNT(*) FROM distance_requests
WHERE status = 'success'
  AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE);
```

## Rate Limits

- **Free Tier**: 100,000 requests/month
- **Warning**: Logged at 80,000 requests (80%)
- **Exceeded**: Returns 429 with HIGH SEVERITY log

## Response Format

```json
{
  "success": true,
  "message": "Distance calculated successfully",
  "data": {
    "distance": {
      "meters": 5150,
      "miles": 3.2,
      "kilometers": 5.15
    },
    "duration": {
      "seconds": 720,
      "minutes": 12,
      "text": "12 min"
    }
  }
}
```

## Testing

```bash
# Run automated tests
./backend/docs/test_distance_api.sh
```

## Monitoring

```bash
# Get usage stats
curl -X GET http://localhost:8080/api/admin/distance/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Check logs for rate limit warnings
grep "HIGH SEVERITY" backend_logs.txt
grep "WARNING.*Mapbox" backend_logs.txt
```

## Database Tables

- `distance_requests` - All API calls logged here
- Enum: `distance_request_status` (success, error, rate_limited, invalid_coordinates, timeout)

## Key Files

| File | Purpose |
|------|---------|
| `models/distance.go` | Data models |
| `services/mapbox.go` | Mapbox API client |
| `repositories/distance_repository.go` | Database access |
| `handlers/distance.go` | HTTP handlers |
| `sql/schema.sql` | Database schema |

## Support

- Documentation: `backend/docs/DISTANCE_API.md`
- Test Script: `backend/docs/test_distance_api.sh`
- Mapbox Status: https://status.mapbox.com/
