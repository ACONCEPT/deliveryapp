# Delivery Application

A comprehensive delivery application with multi-user type support (Customer, Vendor, Driver, Admin) built with Go backend, PostgreSQL database, and Flutter frontend.

## Architecture

This application follows the **Repository Pattern** design with clean separation of concerns:

- **Backend**: Go with Gorilla Mux, PostgreSQL, JWT authentication
- **Database**: PostgreSQL with custom types and triggers
- **Frontend**: Flutter with Material Design 3
- **Deployment**: Docker containers for API and database

## Features

### Current Implementation (Phase 1)
- ✅ Multi-user type authentication (Customer, Vendor, Driver, Admin)
- ✅ JWT-based authentication with token generation
- ✅ Repository pattern for clean data access
- ✅ User profile management for each user type
- ✅ Flutter login UI with confirmation screen
- ✅ Docker containerization
- ✅ Python CLI for database migrations

### User Types
1. **Customer**: End users who order deliveries
2. **Vendor**: Businesses/restaurants providing products
3. **Driver**: Delivery personnel
4. **Admin**: System administrators

## Project Structure

```
delivery_app/
├── backend/                    # Go API server
│   ├── config/                 # Configuration management
│   ├── database/               # Database connection & app container
│   ├── handlers/               # HTTP request handlers
│   ├── models/                 # Data models
│   ├── repositories/           # Data access layer (Repository pattern)
│   ├── sql/                    # Database schema
│   ├── main.go                 # Server entry point
│   ├── middleware.go           # CORS, logging, recovery middleware
│   ├── Dockerfile              # Backend container config
│   └── go.mod                  # Go dependencies
├── frontend/                   # Flutter mobile app
│   ├── lib/
│   │   ├── models/             # Data models
│   │   ├── services/           # API service layer
│   │   ├── screens/            # UI screens
│   │   └── main.dart           # App entry point
│   └── pubspec.yaml            # Flutter dependencies
├── tools/
│   └── cli/                    # Python CLI for migrations
│       ├── cli.py              # Migration tool
│       └── requirements.txt    # Python dependencies
└── docker-compose.yml          # Container orchestration
```

## Getting Started

### Prerequisites
- Docker & Docker Compose
- Go 1.21+ (for local development)
- Flutter 3.0+ (for mobile app development)
- Python 3.8+ (for CLI tool)

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   cd delivery_app
   ```

2. **Start the services**
   ```bash
   docker-compose up -d
   ```

3. **Verify services are running**
   ```bash
   # Check API health
   curl http://localhost:8080/health

   # Check database
   docker-compose ps
   ```

4. **Seed the database** (optional)
   ```bash
   # Install Python dependencies
   pip install -r tools/cli/requirements.txt

   # Run seed command
   DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5432/delivery_app?sslmode=disable" \
   python tools/cli/cli.py seed
   ```

### Local Development Setup

#### Backend Setup

1. **Install Go dependencies**
   ```bash
   cd backend
   go mod download
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run the server**
   ```bash
   go run main.go middleware.go
   ```

#### Frontend Setup

1. **Install Flutter dependencies**
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Update API URL** (for physical device testing)
   Edit `lib/services/api_service.dart` and change the `baseUrl`:
   ```dart
   // For Android emulator
   static const String baseUrl = 'http://10.0.2.2:8080';

   // For iOS simulator
   static const String baseUrl = 'http://localhost:8080';

   // For physical device (replace with your computer's IP)
   static const String baseUrl = 'http://192.168.x.x:8080';
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Database Management

### Python CLI Tool

The CLI tool (`tools/cli/cli.py`) provides database management commands:

```bash
# Set database URL
export DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5432/delivery_app?sslmode=disable"

# Run migrations
python tools/cli/cli.py migrate

# Check database status
python tools/cli/cli.py status

# Reset database (drops all tables)
python tools/cli/cli.py reset

# Seed with sample data
python tools/cli/cli.py seed
```

### Sample Credentials (after seeding)
- **Customer**: `customer1` / `password123`
- **Vendor**: `vendor1` / `password123`
- **Driver**: `driver1` / `password123`
- **Admin**: `admin1` / `password123`

## API Endpoints

### Authentication
- `POST /api/login` - User login
  ```json
  {
    "username": "customer1",
    "password": "password123"
  }
  ```

- `POST /api/signup` - User registration
  ```json
  {
    "username": "newuser",
    "email": "user@example.com",
    "password": "password",
    "user_type": "customer",
    "full_name": "John Doe",
    "phone": "+1234567890"
  }
  ```

### Health Check
- `GET /health` - API health check

## Technology Stack

### Backend
- **Language**: Go 1.21
- **Framework**: Gorilla Mux
- **Database**: PostgreSQL 16
- **ORM**: sqlx
- **Authentication**: JWT (golang-jwt/jwt)
- **Password Hashing**: bcrypt
- **Validation**: go-playground/validator

### Frontend
- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **HTTP Client**: http package
- **UI**: Material Design 3

### DevOps
- **Containerization**: Docker
- **Orchestration**: Docker Compose
- **Database Migrations**: Python CLI tool

## Database Schema

### Core Tables
- `users` - Main user authentication table
- `customers` - Customer profiles
- `vendors` - Vendor/business profiles
- `drivers` - Driver profiles
- `admins` - Admin profiles
- `customer_addresses` - Customer delivery addresses

### Custom Types
- `user_type`: customer, vendor, admin, driver
- `user_status`: active, inactive, suspended

See `backend/sql/schema.sql` for complete schema.

## Repository Pattern

The backend follows a clean repository pattern:

```
HTTP Request → Handler → Repository → Database
```

**Benefits**:
- Clean separation of concerns
- Easy to test with mocks
- Scalable and maintainable
- Follows SOLID principles

## Development Workflow

1. **Make schema changes** in `backend/sql/schema.sql`
2. **Update models** in `backend/models/`
3. **Implement repository methods** in `backend/repositories/`
4. **Create/update handlers** in `backend/handlers/`
5. **Add routes** in `backend/main.go`
6. **Update Flutter models** in `frontend/lib/models/`
7. **Update API service** in `frontend/lib/services/`
8. **Create/update UI** in `frontend/lib/screens/`

## Testing

### Backend Tests
```bash
cd backend
go test -v
```

### API Testing with curl
```bash
# Login
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"customer1","password":"password123"}'

# Signup
curl -X POST http://localhost:8080/api/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "email":"test@example.com",
    "password":"password123",
    "user_type":"customer",
    "full_name":"Test User"
  }'
```

## Environment Variables

### Backend (.env)
```bash
DATABASE_URL=postgres://user:pass@host:port/dbname?sslmode=disable
SERVER_PORT=8080
TOKEN_DURATION=72
ENVIRONMENT=development
```

### JWT Configuration

**CRITICAL**: All instances of JWT_SECRET must match exactly for tokens to work.

```bash
# Development (all environments must use this exact value)
JWT_SECRET=change-this-secret-key-in-production

# Production (generate a strong random secret)
JWT_SECRET=$(openssl rand -base64 32)
```

**Configuration Files to Check:**
- `backend/.env` (line 9)
- `backend/.env.example` (line 9)
- `docker-compose.yml` (line 30)
- `tools/sh/start-backend.sh` (line 46 - default fallback)

**Troubleshooting JWT Errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| `signature is invalid` | JWT_SECRET mismatch | Ensure all config files use same secret |
| `token is expired` | Token older than TOKEN_DURATION | Login again to get new token |
| `token is malformed` | Invalid token format | Check Authorization header format |

**Debug Token Issues (Development Only):**
```bash
# Get token info without validation
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/api/debug/token-info
```

## Docker Configuration

### Services
- **postgres**: PostgreSQL database (port 5432)
- **api**: Go backend API (port 8080)

### Volumes
- `postgres_data`: Persistent database storage

### Networks
- Default bridge network for service communication

## Future Enhancements

### Phase 2: Order Management
- [ ] Product/menu management for vendors
- [ ] Order creation and tracking
- [ ] Shopping cart functionality
- [ ] Order status workflow

### Phase 3: Delivery Features
- [ ] Driver assignment logic
- [ ] Real-time location tracking
- [ ] Route optimization
- [ ] Delivery status updates

### Phase 4: Advanced Features
- [ ] Payment integration
- [ ] Reviews and ratings
- [ ] Push notifications
- [ ] Analytics dashboard
- [ ] Multi-language support

## Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Submit a pull request

## License

Proprietary - All rights reserved

## Support

For issues or questions, please contact the development team.

---

**Built with ❤️ using Go, PostgreSQL, and Flutter**
