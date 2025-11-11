# Shell Scripts - Delivery App

Utility scripts to manage the Delivery App services.

## Available Scripts

### 🚀 Quick Start

**Full Setup (Recommended for first time)**
```bash
./tools/sh/full-setup.sh
```
Sets up everything: database, migrations, test data, and builds backend.

---

### 📦 Database Management

#### Local Development (Docker)

**Setup Database**
```bash
./tools/sh/setup-database.sh
```
- Starts PostgreSQL container (port 5433)
- Waits for database to be healthy
- Runs schema migrations
- Shows database status

**Seed Test Data**
```bash
./tools/sh/seed-database.sh
```
- Seeds database with sample users (customer1, vendor1, driver1, admin1)
- Note: These use plain passwords and won't work with API authentication
- Use API signup endpoint for properly hashed passwords

#### AWS RDS (Production/Staging)

**Migrate RDS Database (Interactive)**
```bash
# Using default dev RDS
./tools/sh/migrate-rds.sh

# Using custom database URL
./tools/sh/migrate-rds.sh "postgres://user:pass@host:5432/dbname?sslmode=require"

# Using environment variable
export DATABASE_URL="postgres://user:pass@rds.amazonaws.com:5432/db?sslmode=require"
./tools/sh/migrate-rds.sh
```
- Tests database connectivity with timeout
- Shows current database state
- **Asks for confirmation** before dropping data
- Drops all existing objects (drop_all.sql)
- Runs schema migration (schema.sql)
- Verifies migration success
- Shows table and row counts

**Quick RDS Migration (No Prompts)**
```bash
./tools/sh/quick-migrate-rds.sh
```
- Fast migration without confirmation prompts
- **⚠️ USE WITH CAUTION** - destroys all data immediately
- Ideal for CI/CD pipelines and automation

**RDS Connection Issues?**

If you get connection timeout errors:

1. **Check Security Group:**
   ```bash
   aws rds describe-db-instances --db-instance-identifier delivery-app-db-dev
   ```

2. **Add Your IP to Security Group:**
   ```bash
   # Get your IP
   curl -s https://api.ipify.org

   # Add to security group (replace sg-xxxxx)
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxx \
     --protocol tcp \
     --port 5432 \
     --cidr YOUR_IP/32
   ```

3. **Test Connection:**
   ```bash
   nc -zv delivery-app-db-dev.cyt2u0ouqtpr.us-east-1.rds.amazonaws.com 5432
   ```

---

### 🔧 Backend Management

**Start Backend Server**
```bash
./tools/sh/start-backend.sh
```
- Loads environment variables from `.env`
- Builds the Go backend
- Starts the API server on port 8080
- Press Ctrl+C to stop

**Environment Variables (.env)**
```bash
DATABASE_URL=postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable
SERVER_PORT=8080
JWT_SECRET=your-secret-key-here
TOKEN_DURATION=72
ENVIRONMENT=development
```

---

### 🛑 Stop Services

**Stop All Services**
```bash
./tools/sh/stop-all.sh
```
- Stops Docker containers
- Kills any running backend processes

---

## Usage Examples

### First Time Setup
```bash
# 1. Full setup (database + migrations + test data + build)
./tools/sh/full-setup.sh

# 2. Start the backend server
./tools/sh/start-backend.sh

# 3. In another terminal, create test users via API
curl -X POST http://localhost:8080/api/signup \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "testcustomer",
    "email": "test@example.com",
    "password": "password123",
    "user_type": "customer",
    "full_name": "Test Customer",
    "phone": "+1234567890"
  }'

# 4. Test login
curl -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "testcustomer",
    "password": "password123"
  }'
```

### Daily Development
```bash
# Start database only
./tools/sh/setup-database.sh

# Start backend (in development mode)
cd backend
go run main.go middleware.go

# Or use the script
./tools/sh/start-backend.sh
```

### Reset Everything
```bash
# Stop all services
./tools/sh/stop-all.sh

# Remove database volume
docker volume rm delivery_app_postgres_data

# Start fresh
./tools/sh/full-setup.sh
```

---

## Script Details

### setup-database.sh
- **Prerequisites**: Docker, docker-compose
- **Creates**: PostgreSQL container, venv (if needed)
- **Configures**: Port 5433, user: delivery_user, db: delivery_app
- **Runs**: Schema migrations via Python CLI

### start-backend.sh
- **Prerequisites**: Go 1.21+, database running
- **Creates**: .env (if missing), compiled binary
- **Runs**: API server with hot reload support
- **Port**: 8080 (configurable via .env)

### seed-database.sh
- **Prerequisites**: Database running, Python CLI setup
- **Creates**: 4 test users (one per user type)
- **Warning**: Uses plain passwords, not for production

### stop-all.sh
- **Stops**: All Docker containers
- **Kills**: Backend processes
- **Safe**: Can be run multiple times

### full-setup.sh
- **Runs**: All setup scripts in order
- **Time**: ~30-60 seconds
- **Idempotent**: Safe to run multiple times

---

## Troubleshooting

### Port Already in Use
If port 5433 is already in use, edit `docker-compose.yml`:
```yaml
ports:
  - "5434:5432"  # Change 5433 to 5434
```

Then update `DATABASE_URL` in scripts to use port 5434.

### Database Won't Start
```bash
# Check Docker is running
docker ps

# Check logs
docker-compose logs postgres

# Reset database
docker-compose down -v
./tools/sh/setup-database.sh
```

### Backend Build Fails
```bash
# Clean build cache
cd backend
go clean
rm -f delivery_app

# Update dependencies
go mod tidy
go mod download

# Try building again
go build -o delivery_app main.go middleware.go
```

### Python CLI Issues
```bash
# Recreate virtual environment
cd tools/cli
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Environment Files

### backend/.env
```bash
# Database
DATABASE_URL=postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable

# Server
SERVER_PORT=8080
ENVIRONMENT=development

# JWT Authentication
JWT_SECRET=change-this-to-a-random-secure-string-in-production
TOKEN_DURATION=72

# Note: JWT_SECRET should be a long random string
# Generate one: openssl rand -base64 32
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `full-setup.sh` | Complete setup from scratch (local) |
| `setup-database.sh` | Start local database + migrations |
| `migrate-rds.sh` | Migrate AWS RDS database (interactive) |
| `quick-migrate-rds.sh` | Migrate AWS RDS (no prompts) |
| `seed-database.sh` | Add test data to local database |
| `start-backend.sh` | Run API server |
| `stop-all.sh` | Stop all local services |

---

## Notes

- All scripts are safe to run multiple times
- Scripts use relative paths, run from any directory
- Database runs on port 5433 to avoid conflicts
- Backend logs to stdout, use `2>&1 | tee backend.log` to save logs
- For production, use Docker Compose instead of these scripts

---

**For questions or issues, see the main README.md**
