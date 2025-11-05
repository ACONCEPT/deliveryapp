# Menu Update Request Logging Analysis

## Issue Report
User reported that PUT requests to update menus are not being logged to stdout.

## Investigation Results

### 1. Route Configuration ✅
**File:** `backend/main.go` (line 181)
```go
vendorRoutes.HandleFunc("/menus/{id}", h.UpdateMenu).Methods("PUT", "OPTIONS")
```

- Route is properly registered under `/api/vendor/menus/{id}`
- Accepts both PUT and OPTIONS methods
- Attached to `vendorRoutes` which requires authentication and vendor role

### 2. Middleware Stack ✅
**File:** `backend/main.go` (lines 249-251)
```go
router.Use(CORSMiddleware)      // Must be first to handle preflight requests
router.Use(RecoveryMiddleware)  // Catch panics
router.Use(LoggingMiddleware)   // Log requests
```

- LoggingMiddleware is properly applied to the root router
- All routes, including vendor routes, pass through this middleware
- Middleware order is correct

### 3. Logging Middleware Implementation ✅
**File:** `backend/middleware.go` (lines 67-102)

The LoggingMiddleware logs **TWO lines** for every request:

**Line 1 - Request Entry** (line 80):
```go
log.Printf("[%s] %s %s", r.Method, r.URL.Path, r.RemoteAddr)
```
Output: `[PUT] /api/vendor/menus/123 127.0.0.1:54321`

**Line 2 - Request Completion** (lines 86-100):
```go
duration := time.Since(start)
statusCode := wrapped.statusCode
log.Printf("[%s] %s completed in %v - ✅ %d (Success)", ...)
```
Output: `[PUT] /api/vendor/menus/123 completed in 234ms - ✅ 200 (Success)`

### 4. Response Writer Wrapper ✅
**File:** `backend/middleware.go` (lines 45-65)

The `responseWriter` struct properly captures status codes:
- Intercepts `WriteHeader()` calls
- Defaults to 200 if not explicitly set
- Prevents duplicate header writes

### 5. Handler Implementation ✅
**File:** `backend/handlers/menu.go` (lines 142-226)

The `UpdateMenu` handler:
- Uses standard response helpers (`sendError`, `sendJSON`)
- All error paths call `sendError` which writes a status code
- Success path calls `sendJSON` with `http.StatusOK`
- No silent returns or missing status codes

## Conclusion

**The logging IS properly configured** and should be logging all menu update requests.

## Possible Explanations for Missing Logs

### 1. **Docker Log Buffering**
Go's `log` package writes to stderr, which might be buffered by Docker.

**Check Docker logs:**
```bash
docker logs -f delivery_app-api-1
```

**Or check with timestamp:**
```bash
docker logs --since 5m delivery_app-api-1
```

### 2. **Log Output Redirection**
If running without Docker, check if stdout/stderr is redirected to a file.

### 3. **Terminal Scrollback**
Logs might be appearing but scrolling past quickly. Try:
```bash
docker logs delivery_app-api-1 | grep "PUT.*menu"
```

### 4. **Request Not Reaching Backend**
- Check if frontend is actually making the PUT request
- Check browser DevTools Network tab
- Verify request URL is correct: `http://localhost:8080/api/vendor/menus/{id}`
- Check for CORS preflight (OPTIONS) request first

### 5. **Wrong Container**
If multiple containers are running, make sure you're watching the correct one:
```bash
docker ps
docker logs -f <correct-container-name>
```

## Expected Log Output

For a successful menu update request, you should see:

```
[PUT] /api/vendor/menus/123 127.0.0.1:54321
[PUT] /api/vendor/menus/123 completed in 245ms - ✅ 200 (Success)
```

For a failed request (e.g., invalid ID):

```
[PUT] /api/vendor/menus/abc 127.0.0.1:54321
[PUT] /api/vendor/menus/abc completed in 5ms - ⚠️  400 (Client Error)
```

For an unauthorized request:

```
[PUT] /api/vendor/menus/123 127.0.0.1:54321
[PUT] /api/vendor/menus/123 completed in 3ms - ⚠️  401 (Client Error)
```

## Verification Steps

### Step 1: Check Docker Logs
```bash
# View all recent logs
docker logs --tail 100 delivery_app-api-1

# Follow logs in real-time
docker logs -f delivery_app-api-1

# Filter for menu updates
docker logs delivery_app-api-1 | grep -i menu
```

### Step 2: Make a Test Request
```bash
# Get JWT token first
TOKEN="your-jwt-token-here"

# Make a test PUT request
curl -X PUT http://localhost:8080/api/vendor/menus/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Menu Name"}'
```

**Watch the Docker logs while making this request.**

### Step 3: Check for CORS Preflight
The browser makes an OPTIONS request before PUT. You should see:
```
[OPTIONS] /api/vendor/menus/123 127.0.0.1:54321
[OPTIONS] /api/vendor/menus/123 completed in 1ms - ↪️  204 (Redirect)
[PUT] /api/vendor/menus/123 127.0.0.1:54321
[PUT] /api/vendor/menus/123 completed in 245ms - ✅ 200 (Success)
```

### Step 4: Check Frontend Network Tab
1. Open browser DevTools (F12)
2. Go to Network tab
3. Trigger menu update in UI
4. Look for PUT request to `/api/vendor/menus/{id}`
5. Check request/response status
6. Verify Authorization header is present

### Step 5: Enable Debug Logging
Add this to `backend/main.go` at the start of `main()`:
```go
log.SetFlags(log.LstdFlags | log.Lshortfile)
log.SetOutput(os.Stdout) // Force stdout instead of stderr
```

## Additional Diagnostic Commands

```bash
# Check if backend is running
docker ps | grep api

# Check backend container logs from the beginning
docker logs delivery_app-api-1

# Check last 50 lines
docker logs --tail 50 delivery_app-api-1

# Check for any errors
docker logs delivery_app-api-1 2>&1 | grep -i error

# Check for PUT requests specifically
docker logs delivery_app-api-1 2>&1 | grep "\[PUT\]"

# Monitor logs and filter for menu routes
docker logs -f delivery_app-api-1 2>&1 | grep menu
```

## Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Request not sent** | No logs at all | Check frontend - request might not be sent |
| **Wrong endpoint** | 404 logs appearing | Verify frontend is calling correct URL |
| **Auth failure** | 401 logs appearing | Check JWT token validity |
| **Buffered output** | Delayed logs | Use `docker logs -f` for real-time |
| **Wrong container** | No relevant logs | Verify correct container with `docker ps` |

## If Still Not Logging

If you've confirmed:
- ✅ Docker logs are streaming (`docker logs -f`)
- ✅ Request is being sent from frontend
- ✅ Request reaches the correct URL
- ✅ No error logs appear

Then there might be an issue with:
1. Log output being captured by a process manager
2. Log rotation truncating output
3. System logging configuration (syslog, journald)

## Recommendation

The most likely explanation is that logs **are** being generated but:
- They're in Docker logs, not terminal output
- They're scrolling past too quickly
- You're looking at the wrong container or terminal

**Use this command to verify:**
```bash
# Make a menu update request, then immediately check logs
docker logs --tail 10 delivery_app-api-1
```

You should see the PUT request and completion logs there.

---

**Status:** Logging is correctly configured ✅
**Action:** Check Docker logs with `docker logs -f delivery_app-api-1`
**Files Verified:**
- `backend/main.go` (route registration, middleware setup)
- `backend/middleware.go` (logging implementation)
- `backend/handlers/menu.go` (handler implementation)
