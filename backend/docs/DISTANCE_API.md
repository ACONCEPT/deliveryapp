# Distance API Documentation

## Overview

The Distance API calculates driving distance and estimated travel time between customer addresses and restaurants using the Mapbox Directions API. All requests are logged for monitoring, analytics, and rate limit tracking.

## Features

- **Real-time Distance Calculation**: Get accurate driving distance and duration
- **Multiple Unit Support**: Results in meters, miles, kilometers
- **Request Logging**: All API calls are tracked in the database
- **Rate Limit Monitoring**: Automatic warnings when approaching Mapbox free tier limits
- **Error Handling**: Graceful handling of API errors, rate limits, and network issues
- **Usage Analytics**: Track daily and monthly API usage

## Mapbox Configuration

### Free Tier Limits
- **100,000 requests/month** (free)
- Automatic logging and warnings at 80% usage
- Upgrade available for higher volumes

### Setup

1. Get your Mapbox access token: https://account.mapbox.com/access-tokens/
2. Add to `.env` file:
   ```
   MAPBOX_ACCESS_TOKEN=your_token_here
   ```

## API Endpoints

### 1. Calculate Distance Estimate

**Endpoint:** `POST /api/distance/estimate`

**Authentication:** Required (JWT Bearer token)

**User Types:** All authenticated users (customer, vendor, driver, admin)

**Request Body:**
```json
{
  "address_id": 1,
  "restaurant_id": 2
}
```

**Validation:**
- `address_id`: Must be greater than 0
- `restaurant_id`: Must be greater than 0
- Both address and restaurant must exist in database
- Both must have valid latitude/longitude coordinates
- Customers can only calculate distance for their own addresses

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Distance calculated successfully",
  "data": {
    "origin": {
      "address_id": 1,
      "address_line1": "123 Main St",
      "address_line2": "Apt 4B",
      "city": "New York",
      "state": "NY",
      "postal_code": "10001",
      "country": "USA",
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    "destination": {
      "restaurant_id": 2,
      "name": "Pizza Palace",
      "address_line1": "456 Broadway",
      "city": "New York",
      "state": "NY",
      "postal_code": "10002",
      "country": "USA",
      "latitude": 40.7589,
      "longitude": -73.9851
    },
    "distance": {
      "meters": 5150,
      "miles": 3.2,
      "kilometers": 5.15
    },
    "duration": {
      "seconds": 720,
      "minutes": 12,
      "text": "12 min"
    },
    "calculated_at": "2025-10-28T20:00:00Z"
  }
}
```

**Error Responses:**

**400 Bad Request** - Invalid input
```json
{
  "success": false,
  "message": "Invalid address_id: must be greater than 0"
}
```

**400 Bad Request** - Missing coordinates
```json
{
  "success": false,
  "message": "Address does not have valid coordinates"
}
```

**403 Forbidden** - Unauthorized access
```json
{
  "success": false,
  "message": "You don't have permission to access this address"
}
```

**404 Not Found** - Resource not found
```json
{
  "success": false,
  "message": "Address not found"
}
```

**429 Too Many Requests** - Rate limit exceeded
```json
{
  "success": false,
  "message": "Rate limit exceeded: Mapbox API free tier limit reached. Please try again later."
}
```

**500 Internal Server Error** - API failure
```json
{
  "success": false,
  "message": "Failed to calculate distance"
}
```

### 2. Get User Distance History

**Endpoint:** `GET /api/distance/history`

**Authentication:** Required (JWT Bearer token)

**User Types:** All authenticated users

**Query Parameters:**
- `per_page` (optional): Number of results (default: 20, max: 100)
- `page` (optional): Page number (default: 1)

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Distance history retrieved successfully",
  "data": [
    {
      "id": 42,
      "user_id": 5,
      "origin_address_id": 1,
      "destination_restaurant_id": 2,
      "origin_latitude": 40.7128,
      "origin_longitude": -74.0060,
      "destination_latitude": 40.7589,
      "destination_longitude": -73.9851,
      "status": "success",
      "distance_meters": 5150,
      "duration_seconds": 720,
      "api_response_time_ms": 234,
      "mapbox_request_id": "req-abc123",
      "created_at": "2025-10-28T20:00:00Z"
    }
  ]
}
```

### 3. Get API Usage Statistics (Admin Only)

**Endpoint:** `GET /api/admin/distance/usage`

**Authentication:** Required (JWT Bearer token)

**User Types:** Admin only

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "API usage retrieved successfully",
  "data": {
    "daily": {
      "count": 127
    },
    "monthly": {
      "count": 3456,
      "limit": 100000,
      "remaining": 96544,
      "usage_percent": "3.46%",
      "approaching_limit": false
    },
    "stats": [
      {
        "date": "2025-10-28",
        "total_requests": 127,
        "successful_count": 120,
        "error_count": 5,
        "rate_limited_count": 2,
        "avg_response_time_ms": 245
      },
      {
        "date": "2025-10-27",
        "total_requests": 134,
        "successful_count": 131,
        "error_count": 3,
        "rate_limited_count": 0,
        "avg_response_time_ms": 238
      }
    ]
  }
}
```

## Request Logging

All distance calculation requests are automatically logged to the `distance_requests` table with the following information:

- **user_id**: User who made the request
- **origin_address_id**: Customer address ID
- **destination_restaurant_id**: Restaurant ID
- **coordinates**: Latitude/longitude for both locations
- **status**: Request outcome (success, error, rate_limited, invalid_coordinates, timeout)
- **distance_meters**: Calculated distance (if successful)
- **duration_seconds**: Estimated travel time (if successful)
- **api_response_time_ms**: Mapbox API response time
- **error_message**: Error details (if failed)
- **mapbox_request_id**: Mapbox request tracking ID
- **created_at**: Request timestamp

## Error Handling

### Rate Limit Handling (HTTP 429)

When Mapbox rate limit is exceeded:
1. Request is logged with status `rate_limited`
2. **HIGH SEVERITY** log message is written with recommendations
3. Client receives `429 Too Many Requests` response
4. Automatic monitoring checks usage levels

**High Severity Log Example:**
```
[HIGH SEVERITY] Mapbox API Rate Limit Exceeded!
  Status: 429 Too Many Requests
  Request ID: req-abc123
  Response Time: 245ms
  Action Required: Review daily API usage and consider caching or paid tier
  Free Tier Limit: 100,000 requests/month
```

### Usage Warnings

At 80% of monthly limit (80,000 requests):
```
[WARNING] Mapbox API Usage Alert!
  Monthly Usage: 80234 / 100000 (80.23%)
  Remaining: 19766 requests
  Recommendation: Consider implementing caching or upgrading to paid tier
```

## Example API Calls

### cURL Examples

**Calculate Distance:**
```bash
curl -X POST http://localhost:8080/api/distance/estimate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "address_id": 1,
    "restaurant_id": 2
  }'
```

**Get Distance History:**
```bash
curl -X GET "http://localhost:8080/api/distance/history?per_page=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Get API Usage (Admin):**
```bash
curl -X GET http://localhost:8080/api/admin/distance/usage \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN"
```

### JavaScript/Fetch Example

```javascript
// Calculate distance
async function calculateDistance(addressId, restaurantId, token) {
  const response = await fetch('http://localhost:8080/api/distance/estimate', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      address_id: addressId,
      restaurant_id: restaurantId
    })
  });

  const data = await response.json();

  if (data.success) {
    console.log(`Distance: ${data.data.distance.miles} miles`);
    console.log(`Duration: ${data.data.duration.text}`);
    return data.data;
  } else {
    console.error(`Error: ${data.message}`);
    throw new Error(data.message);
  }
}

// Usage
calculateDistance(1, 2, 'your-jwt-token')
  .then(result => {
    console.log('Distance calculated:', result);
  })
  .catch(error => {
    console.error('Failed to calculate distance:', error);
  });
```

## Database Schema

### distance_requests Table

```sql
CREATE TABLE distance_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    origin_address_id INTEGER REFERENCES customer_addresses(id) ON DELETE SET NULL,
    destination_restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE SET NULL,

    -- Request details
    origin_latitude DECIMAL(10, 8),
    origin_longitude DECIMAL(11, 8),
    destination_latitude DECIMAL(10, 8),
    destination_longitude DECIMAL(11, 8),

    -- Response details
    status distance_request_status NOT NULL,
    distance_meters INTEGER,
    duration_seconds INTEGER,
    api_response_time_ms INTEGER,
    error_message TEXT,

    -- Metadata
    mapbox_request_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### distance_request_status Enum

```sql
CREATE TYPE distance_request_status AS ENUM (
    'success',
    'error',
    'rate_limited',
    'invalid_coordinates',
    'timeout'
);
```

## Performance Considerations

### Coordinate Validation
- Both origin and destination must have valid latitude/longitude
- Coordinates validated before API call (saves quota)
- Invalid coordinate ranges rejected client-side

### Response Caching (Recommended)
Consider implementing caching for frequently requested routes:
- Cache key: `{address_id}:{restaurant_id}`
- TTL: 7 days (routes change infrequently)
- Reduces API calls by ~70% in typical usage

### Rate Limit Monitoring
- Automatic background checks after each request
- Warning logs at 80% threshold
- Real-time usage dashboard for admins

## Testing Checklist

- [ ] Valid address and restaurant with coordinates
- [ ] Invalid address ID (404 error)
- [ ] Invalid restaurant ID (404 error)
- [ ] Address without coordinates (400 error)
- [ ] Customer accessing another customer's address (403 error)
- [ ] Rate limit simulation (429 error)
- [ ] Network timeout handling
- [ ] Request logging verification
- [ ] Usage statistics accuracy
- [ ] Admin-only usage endpoint access control

## Troubleshooting

### "MAPBOX_ACCESS_TOKEN is not set"
1. Get token from https://account.mapbox.com/access-tokens/
2. Add to `.env` file: `MAPBOX_ACCESS_TOKEN=your_token`
3. Restart backend server

### "Invalid Mapbox access token"
1. Verify token is correct (starts with `pk.` or `sk.`)
2. Check token has not expired
3. Verify token has Directions API scope enabled

### High Response Times
1. Check Mapbox API status: https://status.mapbox.com/
2. Verify network connectivity
3. Check database query performance
4. Consider implementing caching

### Rate Limit Exceeded
1. Check monthly usage: `GET /api/admin/distance/usage`
2. Implement caching for common routes
3. Upgrade to Mapbox paid tier if needed
4. Add daily/monthly quotas per user

## Future Enhancements

- [ ] Response caching with 7-day TTL
- [ ] Alternative routing profiles (walking, cycling)
- [ ] Traffic-aware routing
- [ ] Waypoint support for multi-stop routes
- [ ] Batch distance calculation
- [ ] Geofencing for delivery zones
- [ ] Per-user rate limiting
- [ ] Distance-based delivery fee calculator
