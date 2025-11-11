# Quick Fix Guide - Mapbox Token in Docker

## TL;DR - What Was Fixed

**Problem**: Mapbox token wasn't being passed to the Docker container.

**Solution**: Added `env_file: .env` to docker-compose.yml so Docker Compose reads the token from the root `.env` file.

## Quick Test

Run the automated test script:
```bash
./test_mapbox_fix.sh
```

This will:
1. Rebuild containers
2. Check for Mapbox warning in logs
3. Test the distance API endpoint
4. Report success/failure

## Manual Test

### Step 1: Rebuild Containers
```bash
docker-compose down
docker-compose up --build
```

### Step 2: Check Logs
```bash
docker logs delivery_app_api
```

**What to look for:**
- ✅ **GOOD**: No warning about MAPBOX_ACCESS_TOKEN
- ❌ **BAD**: `[WARNING] MAPBOX_ACCESS_TOKEN is not set`

### Step 3: Test Distance API
```bash
curl -X POST http://localhost:8080/api/distance/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 34.0522, "longitude": -118.2437},
    "destination": {"latitude": 34.0407, "longitude": -118.2468}
  }'
```

**Expected response:**
```json
{
  "success": true,
  "data": {
    "distance_meters": 2845,
    "distance_miles": 1.77,
    "duration_seconds": 420,
    "duration_minutes": 7,
    ...
  }
}
```

## What Changed

### 1. Created `.env` file in project root
```
MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoianNhZGFrYSIsImEiOiJjbWhiYXBnM2gwZDl2MnJvZGdtdDU4Nzk0In0.ZImDFc5783c5AJZs3_VggQ
```

### 2. Updated docker-compose.yml
Added this line to the `api` service:
```yaml
env_file:
  - .env
```

### 3. Updated .env.example
Added setup instructions for new developers.

## Why It Works

**Before:**
- docker-compose.yml used `${MAPBOX_ACCESS_TOKEN:-}` syntax
- This reads from your **shell environment** (not from a file)
- Token wasn't in your shell → container got empty string

**After:**
- docker-compose.yml uses `env_file: .env`
- Docker Compose reads ALL variables from the `.env` file
- Token is automatically passed to the container

## File Structure

```
delivery_app/
├── .env                    # ← NEW: Contains your actual Mapbox token
├── .env.example            # ← UPDATED: Has setup instructions
├── docker-compose.yml      # ← UPDATED: Added env_file directive
└── backend/
    ├── .env                # Used only for local development (not Docker)
    └── config/config.go    # Reads MAPBOX_ACCESS_TOKEN from environment
```

## Troubleshooting

### Still seeing warning after rebuild?

**Check 1**: Verify root .env exists
```bash
cat .env | grep MAPBOX
```

**Check 2**: Verify docker-compose.yml has env_file
```bash
grep "env_file:" docker-compose.yml
```

**Check 3**: Rebuild with --build flag
```bash
docker-compose down
docker-compose up --build
```

### Distance API returns error?

**Check 1**: Verify token is valid
- Go to https://account.mapbox.com/access-tokens/
- Check if token is active
- Verify token has "Navigation" scope enabled

**Check 2**: Check backend logs
```bash
docker logs delivery_app_api
```

**Check 3**: Test with curl (see "Manual Test" above)

## For New Developers

If you're setting up this project for the first time:

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Get your own Mapbox token:
   - Go to https://account.mapbox.com/access-tokens/
   - Create a free account (100,000 requests/month)
   - Copy your token

3. Edit `.env` and replace the token:
   ```bash
   MAPBOX_ACCESS_TOKEN=your_token_here
   ```

4. Start Docker:
   ```bash
   docker-compose up
   ```

## Security Notes

- `.env` is in `.gitignore` (NOT committed to version control)
- `.env.example` is committed (template only, no real secrets)
- Never hardcode tokens in docker-compose.yml or Dockerfile
- The Dockerfile correctly does NOT copy .env files

## Full Documentation

For complete explanation, architecture details, and production deployment:
→ See `MAPBOX_DOCKER_FIX.md`