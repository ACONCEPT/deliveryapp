# Mapbox Token Docker Fix - Summary

## Problem Description

The Mapbox token was not being found in the backend container when launching via Docker Compose. The backend logs showed:
```
[WARNING] MAPBOX_ACCESS_TOKEN is not set - distance API will not work
```

## Root Cause

**Three interconnected issues:**

1. **Missing root `.env` file**: The project had `.env.example` but no actual `.env` file in the root directory
2. **Incorrect docker-compose.yml syntax**: Used `${MAPBOX_ACCESS_TOKEN:-}` which reads from the **shell environment**, not from a file
3. **Environment variable not propagated**: Docker Compose was not configured to read environment variables from a file

### Why This Happened

The original docker-compose.yml had:
```yaml
environment:
  MAPBOX_ACCESS_TOKEN: ${MAPBOX_ACCESS_TOKEN:-}
```

This syntax tells Docker Compose to:
- Read `MAPBOX_ACCESS_TOKEN` from the **host machine's shell environment**
- If not found, use empty string `""`

Since the variable wasn't set in your shell, the container received an empty string.

The backend `.env` file exists but is **only used when running Go locally** (not in Docker).

## Solution Implemented

### 1. Created Root `.env` File

Created `/Users/josephsadaka/Repos/delivery_app/.env` with your actual Mapbox token:
```bash
MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoianNhZGFrYSIsImEiOiJjbWhiYXBnM2gwZDl2MnJvZGdtdDU4Nzk0In0.ZImDFc5783c5AJZs3_VggQ
```

**Note**: This file is already in `.gitignore` and will NOT be committed to version control.

### 2. Updated docker-compose.yml

Added `env_file` directive to the `api` service:
```yaml
api:
  build:
    context: ./backend
    dockerfile: Dockerfile
  container_name: delivery_app_api
  env_file:
    - .env  # Load environment variables from root .env file
  environment:
    # These override values from .env if needed
    DATABASE_URL: postgres://delivery_user:delivery_pass@postgres:5432/delivery_app?sslmode=disable
    SERVER_PORT: 8080
    JWT_SECRET: change-this-secret-key-in-production
    TOKEN_DURATION: 72
    ENVIRONMENT: development
    # MAPBOX_ACCESS_TOKEN will be loaded from .env file
```

**How it works:**
- `env_file: .env` tells Docker Compose to read all variables from the root `.env` file
- Variables in the `environment:` section can override values from `.env` if needed
- `MAPBOX_ACCESS_TOKEN` is now loaded automatically from `.env`

### 3. Updated .env.example with Setup Instructions

Added clear setup instructions for new developers:
```bash
# SETUP INSTRUCTIONS:
# 1. Copy this file to .env in the project root:
#    cp .env.example .env
#
# 2. Get your Mapbox token from: https://account.mapbox.com/access-tokens/
#
# 3. Replace 'your_mapbox_access_token_here' below with your actual token
#
# 4. Run docker-compose up to start the application
```

## Testing the Fix

### Step 1: Rebuild and restart containers

```bash
cd /Users/josephsadaka/Repos/delivery_app

# Stop existing containers
docker-compose down

# Rebuild and start (forces fresh container creation)
docker-compose up --build
```

### Step 2: Verify the token is loaded

Check the backend logs for the success message:
```bash
# In another terminal
docker logs delivery_app_api
```

You should **NOT** see this warning:
```
[WARNING] MAPBOX_ACCESS_TOKEN is not set - distance API will not work
```

### Step 3: Test the distance API

Once the backend is running, test the distance endpoint:

```bash
# Test driving distance calculation
curl -X POST http://localhost:8080/api/distance/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 34.0522, "longitude": -118.2437},
    "destination": {"latitude": 34.0407, "longitude": -118.2468}
  }'
```

Expected response:
```json
{
  "success": true,
  "data": {
    "distance_meters": 2845,
    "distance_miles": 1.77,
    "duration_seconds": 420,
    "duration_minutes": 7,
    "origin": {"latitude": 34.0522, "longitude": -118.2437},
    "destination": {"latitude": 34.0407, "longitude": -118.2468}
  }
}
```

## Architecture Explanation

### Environment Variable Loading Priority

Docker Compose loads environment variables in this order (later overrides earlier):

1. **env_file**: Variables from `.env` file(s)
2. **environment**: Variables explicitly defined in docker-compose.yml
3. **Shell environment**: Variables from your shell (only when using `${VAR}` syntax)

### Why We Don't Copy .env into Docker Images

**Security Best Practice**: The Dockerfile correctly does NOT copy `.env` files because:

1. **Secrets in layers**: Environment files would be baked into Docker image layers (visible in image history)
2. **Image sharing**: Docker images are often pushed to registries; secrets should not be included
3. **Different environments**: Production, staging, and development need different secrets
4. **Runtime flexibility**: Environment variables should be injected at **runtime**, not **build time**

**Correct approach** (what we implemented):
- Build generic images without secrets
- Inject environment variables at runtime via `env_file` or `environment`
- Keep `.env` files in `.gitignore`

### File Structure Summary

```
delivery_app/
├── .env                    # RUNTIME secrets (not committed)
├── .env.example            # Template with setup instructions (committed)
├── .gitignore              # Excludes .env from git
├── docker-compose.yml      # Uses env_file: .env
├── backend/
│   ├── .env                # Used for local Go development only
│   ├── .env.example        # Template for local development
│   ├── Dockerfile          # Does NOT copy .env (correct!)
│   └── config/config.go    # Reads MAPBOX_ACCESS_TOKEN from environment
```

## Alternative Approaches (Not Recommended)

### Option A: Shell Export (Temporary)

```bash
export MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoianNhZGFrYSIsImEiOiJjbWhiYXBnM2gwZDl2MnJvZGdtdDU4Nzk0In0.ZImDFc5783c5AJZs3_VggQ
docker-compose up
```

**Drawback**: Must export every time you open a new terminal.

### Option B: Hardcode in docker-compose.yml (NEVER DO THIS)

```yaml
environment:
  MAPBOX_ACCESS_TOKEN: pk.eyJ1IjoianNhZGFrYSIsImEiOiJjbWhiYXBnM2gwZDl2MnJvZGdtdDU4Nzk0In0.ZImDFc5783c5AJZs3_VggQ
```

**Drawback**: Secrets committed to version control (SECURITY RISK).

### Option C: Copy .env into Dockerfile (ANTI-PATTERN)

```dockerfile
COPY .env .
```

**Drawback**: Secrets baked into Docker image layers (SECURITY RISK).

## Production Deployment

For production, use one of these secure approaches:

### Docker Swarm Secrets
```bash
echo "pk.eyJ..." | docker secret create mapbox_token -
```

### Kubernetes Secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mapbox-secret
stringData:
  MAPBOX_ACCESS_TOKEN: pk.eyJ...
```

### Cloud Provider Secrets Manager
- AWS Secrets Manager
- Google Cloud Secret Manager
- Azure Key Vault

## Troubleshooting

### Issue: Still seeing warning after rebuild

**Solution**: Make sure you rebuild with `--build` flag:
```bash
docker-compose down
docker-compose up --build
```

### Issue: Token not loaded from .env

**Check 1**: Verify .env file exists in root:
```bash
ls -la /Users/josephsadaka/Repos/delivery_app/.env
```

**Check 2**: Verify docker-compose.yml has `env_file` directive:
```bash
grep -A 5 "env_file:" /Users/josephsadaka/Repos/delivery_app/docker-compose.yml
```

**Check 3**: Verify .env has correct format (no quotes):
```bash
# CORRECT
MAPBOX_ACCESS_TOKEN=pk.eyJ...

# WRONG (has quotes)
MAPBOX_ACCESS_TOKEN="pk.eyJ..."
```

### Issue: Permission denied reading .env

**Solution**: Check file permissions:
```bash
chmod 644 /Users/josephsadaka/Repos/delivery_app/.env
```

## Summary of Changes

### Files Modified
1. `/Users/josephsadaka/Repos/delivery_app/.env` - Created with actual token
2. `/Users/josephsadaka/Repos/delivery_app/.env.example` - Added setup instructions
3. `/Users/josephsadaka/Repos/delivery_app/docker-compose.yml` - Added `env_file` directive

### Files Unchanged (Correct Behavior)
1. `backend/Dockerfile` - Still does NOT copy .env (security best practice)
2. `backend/config/config.go` - Already reads `MAPBOX_ACCESS_TOKEN` from environment
3. `.gitignore` - Already excludes `.env` files

## Next Steps

1. **Test the fix**: Follow the testing instructions above
2. **Commit changes**: Commit docker-compose.yml and .env.example (NOT .env)
3. **Update team docs**: Ensure all developers know to copy .env.example to .env
4. **Production setup**: Use proper secrets management for production deployment

## Key Takeaways

1. **Development**: Use `env_file` in docker-compose.yml with local `.env` file
2. **Security**: Never commit `.env` files or hardcode secrets
3. **Docker images**: Never bake secrets into image layers
4. **Production**: Use proper secrets management (Kubernetes secrets, cloud providers, etc.)
5. **Environment variables**: Inject at **runtime**, not **build time**

## References

- Docker Compose env_file: https://docs.docker.com/compose/environment-variables/set-environment-variables/#use-the-env_file-attribute
- Docker secrets: https://docs.docker.com/engine/swarm/secrets/
- Mapbox API: https://docs.mapbox.com/api/navigation/directions/
- Go config package: `/Users/josephsadaka/Repos/delivery_app/backend/config/config.go`