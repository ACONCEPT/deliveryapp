# Docker Setup Guide

## Prerequisites

- Docker Desktop installed and running
- Mapbox account and access token (optional but recommended)

## Quick Start

### 1. Environment Configuration

Copy the example environment file and add your Mapbox token:

```bash
cp .env.example .env
```

Edit `.env` and add your Mapbox access token:

```env
MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoieW91cnVzZXJuYW1lIiwiYSI6ImNsaGJhcGczaDAwZDl2MnJvZGdtdDU4Nzk0In0.example
```

**Get your Mapbox token:**
1. Sign up at https://account.mapbox.com/
2. Go to https://account.mapbox.com/access-tokens/
3. Copy your default public token or create a new one
4. Free tier includes 100,000 requests/month

### 2. Start the Application

```bash
docker-compose up -d
```

This will:
- Start PostgreSQL database on port `5433`
- Start the Go backend API on port `8080`
- Run database migrations automatically
- Create test users

### 3. Verify Setup

Check that containers are running:

```bash
docker-compose ps
```

You should see:
```
NAME                   STATUS
delivery_app_db        Up (healthy)
delivery_app_api       Up
```

Test the API:

```bash
curl http://localhost:8080/health
```

## Database Access

### Connection Details

- **Host**: `localhost`
- **Port**: `5433`
- **Database**: `delivery_app`
- **User**: `delivery_user`
- **Password**: `delivery_pass`

### Connect with psql

```bash
docker exec -it delivery_app_db psql -U delivery_user -d delivery_app
```

### View Database Tables

```sql
\dt
```

### Check Order Tables

```sql
-- View orders table structure
\d orders

-- View order status enum values
SELECT unnest(enum_range(NULL::order_status));

-- Count orders by status
SELECT status, COUNT(*) FROM orders GROUP BY status;
```

## Test Users

The database is seeded with test users:

| Username   | Password    | Type     |
|------------|-------------|----------|
| customer1  | password123 | Customer |
| vendor1    | password123 | Vendor   |
| driver1    | password123 | Driver   |
| admin1     | password123 | Admin    |

### Test Login

```bash
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer1",
    "password": "password123"
  }'
```

## Mapbox Distance API

The application uses Mapbox Directions API for:
- Calculating driving distance between addresses and restaurants
- Estimating delivery time
- Distance-based delivery fees

### Test Distance Calculation

1. Login to get a JWT token
2. Use the `/api/distance/estimate` endpoint:

```bash
TOKEN="your_jwt_token_here"

curl -X POST http://localhost:8080/api/distance/estimate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "address_id": 1,
    "restaurant_id": 1
  }'
```

### Monitor API Usage

Admin users can check Mapbox API usage:

```bash
curl http://localhost:8080/api/admin/distance/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Delivery System Features

### Order Lifecycle

The system supports a complete delivery order flow:

1. **cart** - Customer building order
2. **pending** - Order placed, awaiting vendor confirmation
3. **confirmed** - Vendor confirmed order
4. **preparing** - Vendor preparing food
5. **ready** - Ready for driver pickup
6. **driver_assigned** - Driver assigned to order
7. **picked_up** - Driver picked up from restaurant
8. **in_transit** - Driver en route to customer
9. **delivered** - Order successfully delivered
10. **cancelled** - Order cancelled
11. **refunded** - Payment refunded

### Database Tables

**Core Delivery Tables:**
- `orders` - Main order records with delivery details
  - `delivery_address_id` - Links to customer address
  - `driver_id` - Assigned driver
  - `delivery_fee` - Calculated delivery cost
  - `estimated_delivery_time` - Estimated arrival time

- `order_items` - Line items for each order
  - Historical pricing preservation
  - JSONB customizations

- `order_status_history` - Audit trail for status changes
  - Tracks all order state transitions
  - Records who made changes

- `customer_addresses` - Delivery locations
  - Geocoded with latitude/longitude
  - Support for multiple addresses per customer

- `distance_requests` - Mapbox API usage tracking
  - Logs all distance calculations
  - Monitors API rate limits

**Constraints:**
- Driver assignment safety: Orders can only have driver assigned when status is `ready`
- Driver-status consistency: Enforces valid driver/status combinations
- Single driver per active order: Prevents double-assignment

### System Settings

The database includes delivery-related settings in `system_settings`:

```sql
SELECT setting_key, setting_value, description
FROM system_settings
WHERE category = 'delivery';
```

Key settings:
- `max_delivery_radius_km` (20.0)
- `default_delivery_fee` (5.00)
- `estimated_delivery_time_per_km` (2 minutes)

## Troubleshooting

### Mapbox Token Not Working

**Symptom:** Distance API returns 401 Unauthorized

**Check:**
1. Token is set in `.env` file
2. Token format is correct (starts with `pk.`)
3. Restart Docker containers after changing `.env`:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

**View container environment:**
```bash
docker exec delivery_app_api env | grep MAPBOX
```

### Database Connection Issues

**Symptom:** API can't connect to database

**Check:**
```bash
# Check database health
docker-compose ps

# View database logs
docker-compose logs postgres

# Restart database
docker-compose restart postgres
```

### Port Already in Use

**Symptom:** `Error: port 8080 already in use`

**Solution:**
```bash
# Find process using port
lsof -i :8080

# Kill the process or change port in docker-compose.yml
```

## Stopping the Application

```bash
# Stop containers (preserves data)
docker-compose stop

# Stop and remove containers (preserves data in volumes)
docker-compose down

# Remove everything including volumes (CAUTION: deletes all data)
docker-compose down -v
```

## Logs

```bash
# View all logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View specific service logs
docker-compose logs api
docker-compose logs postgres
```

## Environment Variables Reference

### Backend Container (`delivery_app_api`)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Set in docker-compose | Yes |
| `SERVER_PORT` | API server port | 8080 | Yes |
| `JWT_SECRET` | Secret key for JWT signing | change-this-secret-key-in-production | Yes |
| `TOKEN_DURATION` | JWT token expiration (hours) | 72 | No |
| `ENVIRONMENT` | Runtime environment | development | No |
| `MAPBOX_ACCESS_TOKEN` | Mapbox API token | (from .env file) | No* |

*Required for distance calculation features, but API will run without it (distance endpoints will fail)

## Production Deployment

**Security Checklist:**

1. ✅ Change `JWT_SECRET` to a secure random value
2. ✅ Use strong database password (not `delivery_pass`)
3. ✅ Set `ENVIRONMENT=production`
4. ✅ Use separate Mapbox token for production
5. ✅ Configure proper CORS origins in `middleware.go`
6. ✅ Enable SSL/TLS for database connection
7. ✅ Use environment-specific `.env` files
8. ✅ Set up database backups
9. ✅ Monitor Mapbox API usage limits
10. ✅ Configure proper logging and monitoring

## Additional Resources

- [Backend API Documentation](./backend/openapi.yaml)
- [Database Schema](./backend/sql/schema.sql)
- [Distance API Documentation](./backend/docs/DISTANCE_API.md)
- [Mapbox Directions API](https://docs.mapbox.com/api/navigation/directions/)
