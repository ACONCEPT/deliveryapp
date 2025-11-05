# Driving Distance Calculation Implementation Guide for Delivery App

## Executive Summary

This document provides research, analysis, and recommendations for implementing driving distance calculation between customer addresses and restaurant locations in the delivery app. The app already has:
- Latitude/longitude coordinates stored in database for both addresses and restaurants
- Geocoding capability via OpenStreetMap Nominatim API

**Quick Recommendation**: For development, use **Google Maps Distance Matrix API** with free tier limits. For production at scale, consider **OSRM self-hosted** or **Mapbox** depending on budget and accuracy requirements.

---

## 1. Current Data Review

### What We Have

**Address Model** (`frontend/lib/models/address.dart`):
```dart
class Address {
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final double? latitude;   // ✓ Available for distance calculation
  final double? longitude;  // ✓ Available for distance calculation
  final bool isDefault;
}
```

**Restaurant Model** (`frontend/lib/models/restaurant.dart`):
```dart
class Restaurant {
  final String name;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;   // ✓ Available for distance calculation
  final double? longitude;  // ✓ Available for distance calculation
}
```

**Existing Geocoding Service** (`frontend/lib/services/nominatim_service.dart`):
- Uses OpenStreetMap Nominatim API
- Provides address search with autocomplete
- Supports reverse geocoding (coordinates → address)
- Returns latitude/longitude for addresses

### Data Availability
- **Customer addresses**: Lat/long stored when address is created/updated via geocoding
- **Restaurant addresses**: Lat/long stored in restaurants table
- **Accuracy**: Depends on geocoding quality (Nominatim is generally accurate to building level)

---

## 2. Driving Distance Calculation Options

### Option 1: Google Maps Distance Matrix API

**How It Works:**
- REST API that calculates travel distance and time between origins and destinations
- Uses actual road network data, not straight-line distance
- Supports multiple transportation modes (driving, walking, bicycling, transit)
- Returns both distance and duration
- Can account for real-time traffic conditions (with premium tier)

**API Request Example:**
```http
GET https://maps.googleapis.com/maps/api/distancematrix/json
  ?origins=40.7128,-74.0060
  &destinations=40.7589,-73.9851|40.7614,-73.9776
  &mode=driving
  &units=imperial
  &key=YOUR_API_KEY
```

**API Response Example:**
```json
{
  "rows": [
    {
      "elements": [
        {
          "distance": {
            "text": "3.2 mi",
            "value": 5150  // meters
          },
          "duration": {
            "text": "12 mins",
            "value": 720  // seconds
          },
          "status": "OK"
        }
      ]
    }
  ],
  "status": "OK"
}
```

**Pricing Structure (as of 2025):**
- **Free Tier**: $200 credit per month (approximately 40,000 requests)
- **Standard Pricing**: $5 per 1,000 requests (beyond free tier)
- **Traffic Data**: Additional $5 per 1,000 requests
- **Calculator**: https://mapsplatform.google.com/pricing/

**Cost Examples:**
- 100 orders/day × 30 days = 3,000 requests/month = **FREE**
- 500 orders/day × 30 days = 15,000 requests/month = **FREE**
- 2,000 orders/day × 30 days = 60,000 requests/month = **$100/month**

**Pros:**
- Extremely accurate and reliable
- Real-time traffic data available
- Excellent documentation and SDKs
- Supports batch requests (multiple destinations in one call)
- Global coverage
- Well-maintained and stable

**Cons:**
- Cost can escalate at scale
- Requires API key management
- Rate limits on free tier
- Google's terms of service restrict certain use cases
- API key exposure risk if called from frontend

**Implementation Complexity:** Low (well-documented, many examples)

**Where to Call:**
- **Backend preferred** for API key security
- **Frontend possible** with API key restrictions (domain whitelisting)

**Accuracy:** Excellent (uses actual Google Maps routing data)

**Rate Limits:**
- 100 elements per request
- 100 elements per second per user

---

### Option 2: Mapbox Directions API

**How It Works:**
- REST API similar to Google Maps
- Uses OpenStreetMap data with Mapbox's routing engine
- Supports multiple transportation profiles (driving, walking, cycling)
- Returns turn-by-turn directions along with distance/duration
- Can optimize routes for multiple waypoints

**API Request Example:**
```http
GET https://api.mapbox.com/directions/v5/mapbox/driving/-74.0060,40.7128;-73.9851,40.7589
  ?access_token=YOUR_ACCESS_TOKEN
  &geometries=geojson
```

**API Response Example:**
```json
{
  "routes": [
    {
      "distance": 5150.3,  // meters
      "duration": 720.5,   // seconds
      "geometry": { ... }, // GeoJSON route path
      "legs": [...]
    }
  ],
  "waypoints": [...]
}
```

**Pricing Structure:**
- **Free Tier**: 100,000 requests/month
- **Standard Pricing**: $0.50 per 1,000 requests (beyond free tier)
- **Growth Plan**: Volume discounts available

**Cost Examples:**
- 100 orders/day × 30 days = 3,000 requests/month = **FREE**
- 500 orders/day × 30 days = 15,000 requests/month = **FREE**
- 5,000 orders/day × 30 days = 150,000 requests/month = **$25/month**

**Pros:**
- More generous free tier than Google Maps
- Significantly cheaper at scale
- Modern, developer-friendly API
- Good documentation and SDKs
- Returns full route geometry (useful for map visualization)
- Flexible pricing tiers

**Cons:**
- Slightly less accurate than Google Maps in some regions
- Less comprehensive traffic data
- Smaller ecosystem than Google Maps
- Some areas have less detailed routing data

**Implementation Complexity:** Low (similar to Google Maps)

**Where to Call:**
- **Backend preferred** for token security
- **Frontend possible** with token restrictions

**Accuracy:** Very Good (slightly less than Google in some areas)

**Rate Limits:**
- 300 requests per minute (free tier)
- 600 requests per minute (paid tier)

---

### Option 3: OpenStreetMap Routing APIs

#### A. OSRM (Open Source Routing Machine)

**How It Works:**
- Free and open-source routing engine
- Uses OpenStreetMap data
- Can be self-hosted or used via public servers
- Very fast routing calculations
- Supports car, bike, and foot profiles

**API Request Example (Public Instance):**
```http
GET https://router.project-osrm.org/route/v1/driving/-74.0060,40.7128;-73.9851,40.7589
  ?overview=false
```

**API Response Example:**
```json
{
  "routes": [
    {
      "distance": 5150.3,  // meters
      "duration": 720.5,   // seconds
      "legs": [...]
    }
  ]
}
```

**Deployment Options:**

**Option 3A: Public OSRM Server (router.project-osrm.org)**
- **Cost**: FREE (donation appreciated)
- **Pros**: Zero cost, easy to start
- **Cons**: Rate limited, no SLA, can be unreliable, not for production use
- **Rate Limits**: Unspecified, enforced via fair use policy

**Option 3B: Self-Hosted OSRM**
- **Cost**: Server costs only (AWS t3.medium ~$30/month, larger for global data)
- **Setup**: Docker container, requires preprocessing OSM data
- **Pros**: No per-request costs, full control, no rate limits
- **Cons**: Requires DevOps expertise, server maintenance, data updates

**Self-Hosted Setup Example:**
```bash
# Docker setup
docker run -d -p 5000:5000 \
  -v $(pwd)/osm-data:/data \
  osrm/osrm-backend osrm-routed \
  --algorithm mld /data/north-america-latest.osrm
```

**Pros:**
- Completely free (if self-hosted)
- Very fast routing
- No API keys or tokens required
- Open source (can customize)
- No usage restrictions

**Cons:**
- Less accurate than commercial options
- Self-hosting requires technical expertise
- Data updates needed for accuracy
- Public servers not suitable for production
- Limited support compared to commercial services

**Accuracy:** Good (depends on OSM data quality in your region)

**Implementation Complexity:**
- **Public server**: Low
- **Self-hosted**: High (Docker, data management, DevOps)

---

#### B. GraphHopper

**How It Works:**
- Open-source routing engine (like OSRM)
- Uses OpenStreetMap data
- Can be self-hosted or use commercial cloud service
- Supports multiple vehicle profiles

**Deployment Options:**

**Option 3B1: Self-Hosted GraphHopper**
- Similar to self-hosted OSRM
- **Cost**: Server costs only
- **Pros**: Free, open source, customizable
- **Cons**: Requires setup and maintenance

**Option 3B2: GraphHopper Cloud API**
- **Free Tier**: 500 requests/day
- **Pricing**: Starts at €49/month for 100,000 requests
- **Pros**: Managed service, good documentation
- **Cons**: More expensive than Mapbox, less popular

**Accuracy:** Good (similar to OSRM)

**Implementation Complexity:**
- **Self-hosted**: High
- **Cloud API**: Low

---

### Option 4: Other Commercial APIs

#### A. HERE Maps API

**How It Works:**
- Commercial routing API similar to Google Maps
- Strong coverage in Europe and automotive industry
- Used by many car manufacturers

**Pricing:**
- **Free Tier**: 250,000 transactions/month
- **Freemium Plan**: $1 per 1,000 requests (beyond free tier)

**Pros:**
- Very generous free tier
- Good accuracy, especially in Europe
- Automotive-grade routing

**Cons:**
- Complex pricing structure
- Less popular than Google/Mapbox (fewer code examples)
- API documentation can be overwhelming

**Accuracy:** Excellent

---

#### B. TomTom Routing API

**How It Works:**
- Commercial routing API
- Strong traffic data integration
- Used by GPS navigation devices

**Pricing:**
- **Free Tier**: 2,500 requests/day
- **Pricing**: Varies by volume, starts around €0.50 per 1,000 requests

**Pros:**
- Good free tier
- Strong traffic data
- Accurate routing

**Cons:**
- Less developer-friendly than Google/Mapbox
- Smaller ecosystem

**Accuracy:** Excellent

---

#### C. Azure Maps

**How It Works:**
- Microsoft's mapping and routing service
- Integrated with Azure cloud services

**Pricing:**
- **Free Tier**: 1,000 requests/month (very limited)
- **S0 Tier**: Starts at $0.50 per 1,000 requests

**Pros:**
- Good if already using Azure ecosystem
- Enterprise support

**Cons:**
- Small free tier
- Less popular than Google/Mapbox
- Requires Azure account

**Accuracy:** Very Good

---

## 3. Implementation Approaches

### Approach A: Frontend-Only Calculation

**How It Works:**
- Flutter app calls routing API directly
- No backend changes needed
- Results used immediately in UI

**Pseudo-Code Example:**
```dart
// Frontend service
class DistanceService {
  final String apiKey = 'YOUR_API_KEY'; // ⚠️ Exposed in frontend

  Future<DistanceResult> calculateDistance(
    Address origin,
    Restaurant destination
  ) async {
    final url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${origin.latitude},${origin.longitude}'
        '&destinations=${destination.latitude},${destination.longitude}'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    return DistanceResult(
      distanceMeters: data['rows'][0]['elements'][0]['distance']['value'],
      durationSeconds: data['rows'][0]['elements'][0]['duration']['value'],
    );
  }
}

// Usage in UI
final distance = await distanceService.calculateDistance(
  customerAddress,
  restaurant
);

print('Distance: ${distance.distanceMeters / 1609.34} miles');
print('Duration: ${distance.durationSeconds / 60} minutes');
```

**Architecture Diagram:**
```
┌─────────────┐
│   Flutter   │
│     App     │
└──────┬──────┘
       │ HTTP Request
       │ (lat/long → distance)
       ▼
┌─────────────────┐
│  Google Maps /  │
│  Mapbox API     │
└─────────────────┘
```

**Pros:**
- Simple implementation (no backend changes)
- Real-time calculation
- Fast response (direct API call)
- Easy to iterate during development

**Cons:**
- **API key exposed** in frontend code (security risk)
- Rate limiting per device (harder to manage)
- Client needs network access to external API
- Harder to cache results
- No centralized logging/monitoring
- Can't use IP-restricted API keys

**When to Use:**
- Prototyping and development
- Low-security requirements
- Small user base
- One-time calculations

**Security Mitigation:**
- Use API key restrictions (allowed domains, IP addresses)
- Set usage quotas
- Monitor for abuse

---

### Approach B: Backend Calculation

**How It Works:**
- Backend endpoint accepts origin/destination coordinates
- Backend calls routing API with server-side key
- Returns distance/duration to frontend

**Pseudo-Code Example:**

**Backend (Go):**
```go
// New handler in handlers/distance.go
package handlers

type DistanceRequest struct {
    OriginLat      float64 `json:"origin_lat"`
    OriginLon      float64 `json:"origin_lon"`
    DestinationLat float64 `json:"destination_lat"`
    DestinationLon float64 `json:"destination_lon"`
}

type DistanceResponse struct {
    DistanceMeters  int     `json:"distance_meters"`
    DistanceMiles   float64 `json:"distance_miles"`
    DurationSeconds int     `json:"duration_seconds"`
    DurationMinutes float64 `json:"duration_minutes"`
}

func (h *Handler) CalculateDistance(w http.ResponseWriter, r *http.Request) {
    var req DistanceRequest
    json.NewDecoder(r.Body).Decode(&req)

    // Call Google Maps API from backend
    apiKey := os.Getenv("GOOGLE_MAPS_API_KEY")
    url := fmt.Sprintf(
        "https://maps.googleapis.com/maps/api/distancematrix/json?"+
        "origins=%f,%f&destinations=%f,%f&key=%s",
        req.OriginLat, req.OriginLon,
        req.DestinationLat, req.DestinationLon,
        apiKey,
    )

    resp, _ := http.Get(url)
    // Parse response...

    sendJSON(w, 200, DistanceResponse{
        DistanceMeters:  distanceMeters,
        DistanceMiles:   float64(distanceMeters) / 1609.34,
        DurationSeconds: durationSeconds,
        DurationMinutes: float64(durationSeconds) / 60.0,
    })
}
```

**Frontend (Dart):**
```dart
// New method in services/api_service.dart
class ApiService {
  Future<DistanceResult> calculateDistance(
    double originLat, double originLon,
    double destLat, double destLon,
    String token
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/distance/calculate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'origin_lat': originLat,
        'origin_lon': originLon,
        'destination_lat': destLat,
        'destination_lon': destLon,
      }),
    );

    return DistanceResult.fromJson(json.decode(response.body));
  }
}
```

**Architecture Diagram:**
```
┌─────────────┐
│   Flutter   │
│     App     │
└──────┬──────┘
       │ POST /api/distance/calculate
       │ {origin_lat, origin_lon, dest_lat, dest_lon}
       ▼
┌─────────────┐
│  Go Backend │
│   (API Key  │
│   Secured)  │
└──────┬──────┘
       │ HTTP Request
       │ (with API key)
       ▼
┌─────────────────┐
│  Google Maps /  │
│  Mapbox API     │
└─────────────────┘
```

**Pros:**
- **API key secured** (not exposed to clients)
- Centralized rate limiting
- Centralized logging and monitoring
- Can implement caching layer
- Can add business logic (filtering, validation)
- Easier to switch providers
- Can use IP-restricted API keys

**Cons:**
- Requires backend changes
- Additional network hop (slower)
- Backend becomes single point of failure
- More complex to implement

**When to Use:**
- Production applications
- High-security requirements
- Need centralized monitoring
- Want to implement caching
- Multiple clients (iOS, Android, Web)

---

### Approach C: Pre-Calculated Distances (Cached)

**How It Works:**
- Calculate distances in advance (batch job)
- Store in database
- Serve from cache instantly
- Periodically recalculate

**Database Schema Addition:**
```sql
CREATE TABLE distance_cache (
    id SERIAL PRIMARY KEY,
    origin_type VARCHAR(20) NOT NULL,  -- 'address' or 'restaurant'
    origin_id INTEGER NOT NULL,
    destination_type VARCHAR(20) NOT NULL,
    destination_id INTEGER NOT NULL,
    distance_meters INTEGER NOT NULL,
    duration_seconds INTEGER NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE(origin_type, origin_id, destination_type, destination_id)
);

CREATE INDEX idx_distance_cache_origin ON distance_cache(origin_type, origin_id);
CREATE INDEX idx_distance_cache_destination ON distance_cache(destination_type, destination_id);
CREATE INDEX idx_distance_cache_expires ON distance_cache(expires_at);
```

**Pseudo-Code Example:**

**Batch Calculation Job (Runs nightly):**
```go
// tools/scripts/calculate_distances.go
func CalculateAllDistances() {
    // Get all active customer addresses
    addresses := getActiveAddresses()

    // Get all active restaurants
    restaurants := getActiveRestaurants()

    // Calculate distances for all combinations
    for _, address := range addresses {
        for _, restaurant := range restaurants {
            distance := callDistanceAPI(address, restaurant)

            // Store in database
            upsertDistanceCache(
                "address", address.ID,
                "restaurant", restaurant.ID,
                distance,
            )
        }
    }
}
```

**Runtime Lookup:**
```go
func (h *Handler) GetRestaurantsNearAddress(w http.ResponseWriter, r *http.Request) {
    addressID := getAddressIDFromRequest(r)

    // Query pre-calculated distances
    query := `
        SELECT r.*, dc.distance_meters, dc.duration_seconds
        FROM restaurants r
        JOIN distance_cache dc ON dc.destination_id = r.id
        WHERE dc.origin_type = 'address'
          AND dc.origin_id = $1
          AND dc.destination_type = 'restaurant'
          AND r.is_active = true
        ORDER BY dc.distance_meters ASC
        LIMIT 20
    `

    restaurants := queryDatabase(query, addressID)
    sendJSON(w, 200, restaurants)
}
```

**Architecture Diagram:**
```
┌──────────────────┐
│  Nightly Batch   │
│      Job         │
└────────┬─────────┘
         │ Calculate & Store
         ▼
┌──────────────────┐
│  distance_cache  │
│     Table        │
└────────┬─────────┘
         │ SELECT
         ▼
┌──────────────────┐
│   Go Backend     │
│  (instant query) │
└────────┬─────────┘
         │ JSON Response
         ▼
┌──────────────────┐
│   Flutter App    │
└──────────────────┘
```

**Pros:**
- **Instant response** (database query only)
- No external API calls at runtime
- Predictable performance
- No rate limiting concerns
- Can calculate distance-based pricing consistently
- Supports complex queries (find all restaurants within X miles)

**Cons:**
- Stale data (not real-time)
- Storage requirements (N addresses × M restaurants)
- Batch job complexity
- Doesn't reflect traffic changes
- New addresses need calculation
- Requires periodic recalculation

**Storage Calculation:**
- 1,000 customers × 100 restaurants = 100,000 rows
- Each row ~50 bytes = 5 MB total
- Very manageable

**When to Use:**
- Need fast response times
- Distance doesn't change frequently
- Serving many requests for same routes
- Cost-sensitive (minimize API calls)
- Offline-first applications

**Recalculation Strategy:**
- Daily batch job for all distances
- On-demand for new addresses (cache-aside pattern)
- Expire after 7 days to force refresh

---

### Approach D: Hybrid (Real-Time + Cache)

**How It Works:**
- Check cache first
- If not cached or expired, calculate in real-time
- Store result in cache for future use
- Best of both worlds

**Pseudo-Code Example:**
```go
func (h *Handler) GetDistance(w http.ResponseWriter, r *http.Request) {
    var req DistanceRequest
    json.NewDecoder(r.Body).Decode(&req)

    // Try cache first
    cached := queryDistanceCache(req.OriginID, req.DestinationID)
    if cached != nil && cached.ExpiresAt.After(time.Now()) {
        // Cache hit!
        sendJSON(w, 200, cached)
        return
    }

    // Cache miss - calculate in real-time
    distance := callDistanceAPI(req.Origin, req.Destination)

    // Store in cache (expires in 7 days)
    upsertDistanceCache(
        req.OriginID, req.DestinationID,
        distance,
        time.Now().Add(7 * 24 * time.Hour),
    )

    sendJSON(w, 200, distance)
}
```

**Cache-Aside Pattern:**
```
┌─────────────┐
│  Request    │
└──────┬──────┘
       │
       ▼
   ┌───────┐
   │ Cache?│
   └───┬───┘
       │
   ┌───▼───────┐
   │  HIT      │──────┐
   └───────────┘      │
                      │
   ┌───────────┐      │
   │  MISS     │      │
   └───┬───────┘      │
       │              │
       ▼              │
   ┌───────┐          │
   │  API  │          │
   │  Call │          │
   └───┬───┘          │
       │              │
       ▼              │
   ┌───────┐          │
   │ Store │          │
   │ Cache │          │
   └───┬───┘          │
       │              │
       └──────────────▼
       ┌──────────────┐
       │   Return     │
       │   Result     │
       └──────────────┘
```

**Pros:**
- Fast for repeated routes
- Fresh data for new routes
- Reduces API costs
- Graceful degradation (cache miss → real-time)
- Automatically builds cache over time

**Cons:**
- Most complex implementation
- Cache invalidation challenges
- First request always slow (cache miss)
- Still requires API key management

**When to Use:**
- Production at scale
- Need both speed and freshness
- Budget-conscious but need real-time option
- High traffic with repeated routes

---

## 4. Use Cases in Delivery App

### Use Case 1: Delivery Fee Calculation

**Description:** Calculate delivery fee based on distance from restaurant to customer address.

**Example Pricing Logic:**
```dart
double calculateDeliveryFee(int distanceMeters) {
  const baseFee = 2.99;
  const perMileFee = 0.50;

  double distanceMiles = distanceMeters / 1609.34;

  if (distanceMiles <= 2.0) {
    return baseFee;
  } else {
    return baseFee + ((distanceMiles - 2.0) * perMileFee);
  }
}

// Examples:
// 1 mile → $2.99
// 3 miles → $3.49
// 5 miles → $4.49
```

**When to Calculate:**
- At checkout (before order placement)
- Display on restaurant cards (browse screen)

**Recommended Approach:**
- **Development**: Approach A (Frontend-only, Google Maps free tier)
- **Production**: Approach C or D (Pre-calculated or hybrid)

---

### Use Case 2: Restaurant Search/Filtering

**Description:** Show customers only restaurants within delivery range (e.g., 10 miles).

**Example Query:**
```dart
// Filter restaurants by distance
List<Restaurant> getRestaurantsWithinRange(
  Address customerAddress,
  double maxDistanceMiles,
) {
  return allRestaurants
      .where((r) => calculateDistance(customerAddress, r) <= maxDistanceMiles)
      .toList();
}
```

**UI Implementation:**
```dart
// Restaurant list with distance
ListTile(
  title: Text(restaurant.name),
  subtitle: Text('${distance.toStringAsFixed(1)} mi away · ${duration} min'),
  trailing: Text('\$${deliveryFee.toStringAsFixed(2)}'),
)
```

**Recommended Approach:**
- **Approach C** (Pre-calculated) - instant filtering
- Update nightly batch job

---

### Use Case 3: Driver Assignment

**Description:** Assign order to nearest available driver.

**Example Logic:**
```go
func AssignDriver(order *Order) (*Driver, error) {
    restaurant := getRestaurant(order.RestaurantID)
    availableDrivers := getAvailableDrivers()

    var closestDriver *Driver
    var minDistance int = math.MaxInt32

    for _, driver := range availableDrivers {
        distance := getDistanceFromCache(
            "driver", driver.ID,
            "restaurant", restaurant.ID,
        )

        if distance < minDistance {
            minDistance = distance
            closestDriver = driver
        }
    }

    return closestDriver, nil
}
```

**Recommended Approach:**
- **Approach D** (Hybrid) - real-time driver locations
- Cache expires quickly (5 minutes) due to movement

---

### Use Case 4: Delivery Time Estimation

**Description:** Estimate delivery time including prep time + driving time.

**Example Calculation:**
```dart
class DeliveryEstimate {
  final int prepTimeMinutes;
  final int drivingTimeMinutes;
  final int totalMinutes;

  factory DeliveryEstimate.calculate(
    Restaurant restaurant,
    DistanceResult distance,
  ) {
    int prepTime = restaurant.averagePrepTime ?? 15;
    int drivingTime = (distance.durationSeconds / 60).ceil();

    return DeliveryEstimate(
      prepTimeMinutes: prepTime,
      drivingTimeMinutes: drivingTime,
      totalMinutes: prepTime + drivingTime,
    );
  }
}

// Display: "Estimated delivery: 30-40 min"
```

**Recommended Approach:**
- **Approach B or D** - real-time for accuracy

---

### Use Case 5: Service Area Validation

**Description:** Verify customer address is within restaurant's delivery radius.

**Example Validation:**
```go
func ValidateServiceArea(addressID int, restaurantID int) bool {
    distance := getDistance(addressID, restaurantID)

    restaurant := getRestaurant(restaurantID)
    maxDeliveryDistance := restaurant.MaxDeliveryDistanceMeters

    return distance.DistanceMeters <= maxDeliveryDistance
}

// At checkout
if !ValidateServiceArea(order.AddressID, order.RestaurantID) {
    return errors.New("Restaurant does not deliver to this address")
}
```

**Recommended Approach:**
- **Approach C** (Pre-calculated) - instant validation

---

## 5. Cost Analysis

### Scenario 1: Small Scale (100 orders/day)

**Assumptions:**
- 100 orders/day
- 2 distance calculations per order (customer→restaurant, restaurant→driver)
- 200 API calls/day × 30 days = 6,000 calls/month

**Cost Comparison:**

| Provider | Monthly Cost | Notes |
|----------|--------------|-------|
| Google Maps | **FREE** | Well under 40,000 free requests |
| Mapbox | **FREE** | Well under 100,000 free requests |
| OSRM (Public) | **FREE** | No guarantees |
| OSRM (Self-Hosted) | **$30** | AWS t3.small server |
| HERE Maps | **FREE** | Well under 250,000 free transactions |

**Recommendation:** Google Maps or Mapbox (free tier)

---

### Scenario 2: Medium Scale (500 orders/day)

**Assumptions:**
- 500 orders/day
- 2 distance calculations per order
- 1,000 API calls/day × 30 days = 30,000 calls/month

**Cost Comparison:**

| Provider | Monthly Cost | Notes |
|----------|--------------|-------|
| Google Maps | **FREE** | Still under 40,000 free requests |
| Mapbox | **FREE** | Well under 100,000 free requests |
| OSRM (Self-Hosted) | **$30** | AWS t3.small |
| HERE Maps | **FREE** | Well under 250,000 free transactions |

**Recommendation:** Google Maps or Mapbox (free tier sufficient)

---

### Scenario 3: Large Scale (2,000 orders/day)

**Assumptions:**
- 2,000 orders/day
- 2 distance calculations per order
- 4,000 API calls/day × 30 days = 120,000 calls/month

**Cost Comparison:**

| Provider | Monthly Cost | Calculation |
|----------|--------------|-------------|
| Google Maps | **$400** | (120k - 40k free) × $5/1000 |
| Mapbox | **$10** | (120k - 100k free) × $0.50/1000 |
| OSRM (Self-Hosted) | **$60** | AWS t3.medium + storage |
| HERE Maps | **FREE** | Still under 250,000 free transactions |

**Recommendation:** HERE Maps (free) or Mapbox ($10)

---

### Scenario 4: Enterprise Scale (10,000 orders/day)

**Assumptions:**
- 10,000 orders/day
- 2 distance calculations per order
- 20,000 API calls/day × 30 days = 600,000 calls/month

**Cost Comparison:**

| Provider | Monthly Cost | Calculation |
|----------|--------------|-------------|
| Google Maps | **$2,800** | (600k - 40k free) × $5/1000 |
| Mapbox | **$250** | (600k - 100k free) × $0.50/1000 |
| OSRM (Self-Hosted) | **$150** | AWS t3.large + storage |
| HERE Maps | **$350** | (600k - 250k free) × $1/1000 |

**Recommendation:** OSRM self-hosted ($150) or Mapbox ($250)

---

### Cost with Caching (Approach C or D)

**Scenario: 2,000 orders/day with 90% cache hit rate**

**Assumptions:**
- 2,000 orders/day × 2 calculations = 4,000 calculations needed
- 90% served from cache (3,600 cached, 400 API calls)
- 400 API calls/day × 30 days = 12,000 calls/month

**Cost Comparison:**

| Provider | Monthly Cost | Notes |
|----------|--------------|-------|
| Google Maps | **FREE** | Under 40,000 free requests |
| Mapbox | **FREE** | Under 100,000 free requests |
| OSRM (Self-Hosted) | **$30** | Minimal API calls |

**Cache Storage Cost:**
- 1,000 customers × 100 restaurants = 100,000 rows
- ~5 MB data
- **Negligible** storage cost

**Key Insight:** Caching reduces API costs by 90% and eliminates cost concerns even at scale.

---

## 6. Recommendations

### Development Phase

**Recommended Setup:**
1. **Provider**: Google Maps Distance Matrix API
2. **Approach**: Approach A (Frontend-only)
3. **Why**:
   - Zero implementation time (no backend changes)
   - Free tier sufficient for development
   - Easy to test and iterate
   - Well-documented with many examples

**Implementation Steps:**
1. Get Google Maps API key from Google Cloud Console
2. Create `distance_service.dart` in `frontend/lib/services/`
3. Call API directly from Flutter
4. Display distance/duration in UI

**Security for Development:**
- Restrict API key to HTTP referrer (localhost:*)
- Set daily quota to prevent abuse

---

### Production - Small Scale (< 500 orders/day)

**Recommended Setup:**
1. **Provider**: Mapbox Directions API
2. **Approach**: Approach B (Backend calculation)
3. **Why**:
   - More generous free tier than Google (100k vs 40k)
   - Cheaper if you exceed free tier ($0.50 vs $5 per 1k)
   - API key secured in backend
   - Clean separation of concerns

**Implementation Steps:**
1. Add `MAPBOX_ACCESS_TOKEN` to backend `.env`
2. Create `/api/distance/calculate` endpoint in Go backend
3. Update `api_service.dart` to call backend endpoint
4. Use distances in checkout, restaurant list, etc.

**Cost**: **FREE** (under 100k requests/month)

---

### Production - Medium Scale (500-2,000 orders/day)

**Recommended Setup:**
1. **Provider**: Mapbox Directions API
2. **Approach**: Approach D (Hybrid - cache + real-time)
3. **Why**:
   - Fast response for repeated routes (90%+ cache hit rate)
   - Real-time for new routes
   - Reduces API costs significantly
   - Graceful degradation

**Implementation Steps:**
1. Add `distance_cache` table to database
2. Implement cache-aside pattern in backend
3. Set 7-day TTL for cached distances
4. Monitor cache hit rate

**Cost**: **FREE to $50/month** (depending on cache hit rate)

---

### Production - Large Scale (2,000+ orders/day)

**Recommended Setup:**
1. **Provider**: OSRM (Self-Hosted)
2. **Approach**: Approach C (Pre-calculated) with D (Hybrid fallback)
3. **Why**:
   - No per-request costs
   - Instant response times
   - Full control over routing data
   - Predictable infrastructure costs

**Implementation Steps:**
1. Set up OSRM Docker container on AWS/DigitalOcean
2. Download and process OSM data for your region (North America)
3. Implement nightly batch job to pre-calculate all distances
4. Store in `distance_cache` table
5. Fallback to real-time OSRM API for cache misses

**Infrastructure:**
- AWS t3.medium ($30/month) + EBS storage ($10/month)
- Total: **$40-60/month** regardless of volume

**Alternative:** If accuracy is critical, use Mapbox with caching (~$250/month at 10k orders/day)

---

## 7. Summary Table: Comparison of All Options

| Provider | Free Tier | Paid Pricing | Accuracy | Coverage | Complexity | Best For |
|----------|-----------|--------------|----------|----------|------------|----------|
| **Google Maps** | 40k req/mo | $5/1k | Excellent | Global | Low | Production apps, high accuracy needs |
| **Mapbox** | 100k req/mo | $0.50/1k | Very Good | Global | Low | **Recommended for production** |
| **OSRM (Public)** | Unlimited | FREE | Good | Global | Low | Development only |
| **OSRM (Self-Host)** | N/A | $40-60/mo | Good | Regional | High | High-volume apps (10k+ orders/day) |
| **GraphHopper (Self)** | N/A | $40-60/mo | Good | Regional | High | Alternative to OSRM |
| **GraphHopper (Cloud)** | 500/day | €49/mo | Good | Global | Low | Small apps, open-source preference |
| **HERE Maps** | 250k/mo | $1/1k | Excellent | Global | Medium | High free tier needs |
| **TomTom** | 2.5k/day | €0.50/1k | Excellent | Global | Medium | Traffic-heavy use cases |
| **Azure Maps** | 1k/mo | $0.50/1k | Very Good | Global | Medium | Azure ecosystem integration |

---

## 8. Implementation Roadmap

### Phase 1: MVP (Development)

**Goal:** Get distance calculation working quickly for testing

**Tasks:**
1. Sign up for Google Maps API (or Mapbox)
2. Create frontend `DistanceService` class
3. Add distance display to restaurant cards
4. Calculate delivery fee at checkout

**Timeline:** 1-2 days
**Cost:** FREE
**Approach:** Frontend-only (Approach A)

---

### Phase 2: Production Ready

**Goal:** Secure API keys and optimize for production

**Tasks:**
1. Move distance calculation to backend
2. Add `/api/distance/calculate` endpoint
3. Secure API key in backend environment
4. Add error handling and fallbacks
5. Implement rate limiting

**Timeline:** 3-5 days
**Cost:** FREE (under 100k requests/month)
**Approach:** Backend calculation (Approach B)

---

### Phase 3: Performance Optimization

**Goal:** Reduce API costs and improve response times

**Tasks:**
1. Add `distance_cache` database table
2. Implement cache-aside pattern
3. Add batch calculation job (optional)
4. Monitor cache hit rate
5. Tune cache TTL

**Timeline:** 5-7 days
**Cost:** FREE to $50/month
**Approach:** Hybrid (Approach D)

---

### Phase 4: Scale (if needed)

**Goal:** Support high volume at low cost

**Tasks:**
1. Evaluate OSRM self-hosting
2. Set up OSRM infrastructure
3. Implement nightly pre-calculation job
4. Migrate to pre-calculated distances
5. Keep real-time as fallback

**Timeline:** 2-3 weeks
**Cost:** $40-60/month (infrastructure only)
**Approach:** Pre-calculated + hybrid (Approach C + D)

---

## Conclusion

For the delivery app, the recommended path forward is:

1. **Start with Mapbox** for its generous free tier and low cost at scale
2. **Implement backend calculation** (Approach B) for security
3. **Add caching** (Approach D) when traffic grows
4. **Consider self-hosted OSRM** only at very high volumes (10k+ orders/day)

This provides a clear path from development to enterprise scale with minimal friction and predictable costs.
