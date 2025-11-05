# Menu Update PUT Request Not Appearing in Backend Logs - Debug Guide

## Problem
When saving a menu in the frontend, the PUT request is not showing up in Docker backend logs.

## Frontend Code Path

### 1. Menu Builder Screen
**File:** `frontend/lib/screens/menu_builder_screen.dart` (lines 45-91)

When user clicks "Save":
```dart
Future<void> _saveMenu() async {
  // Line 61: Calls menu service
  await _menuService.updateMenu(
    widget.token,
    updatedMenu.id!,
    updatedMenu,
  );
}
```

### 2. Menu Service
**File:** `frontend/lib/services/menu_service.dart` (lines 69-80)

```dart
Future<Menu> updateMenu(String token, int menuId, dynamic menuData) async {
  final body = menuData is Menu ? menuData.toJson() : (menuData as UpdateMenuRequest).toJson();

  return putObject(
    '/api/vendor/menus/$menuId',  // ← Request path
    'menu',
    body,
    Menu.fromJson,
    token: token,
  );
}
```

### 3. Base Service
**File:** `frontend/lib/services/base_service.dart` (lines 248-279)

```dart
Future<T> putObject<T>(...) async {
  final headers = token != null ? authHeaders(token) : null;
  final response = await httpClient.put(  // ← Calls HTTP client
    path,
    headers: headers,
    body: body,
  );
}
```

### 4. HTTP Client Service
**File:** `frontend/lib/services/http_client_service.dart` (lines 190-226)

```dart
Future<http.Response> put(String path, ...) async {
  final url = '$baseUrl$path';  // ← Should be http://localhost:8080/api/vendor/menus/{id}

  _logRequest('PUT', url, requestHeaders, body: bodyString);  // ← Frontend logs HERE

  final response = await http.put(
    Uri.parse(url),
    headers: requestHeaders,
    body: bodyString,
  ).timeout(timeout ?? ApiConfig.requestTimeout);

  _logResponse('PUT', url, response.statusCode, response.body);  // ← Logs response
}
```

## Diagnostic Steps

### Step 1: Check Frontend Console Logs

Open browser DevTools (F12) and check the console for:

```
🔵 REQUEST: PUT http://localhost:8080/api/vendor/menus/{id}
Headers:
{
  "authorization": "Bearer ...",
  "content-type": "application/json"
}
Body:
{
  "name": "...",
  "menu_config": "..."
}
```

**If you DON'T see this log:**
- The `_saveMenu()` method might not be called
- Check if save button is properly wired up
- Check for JavaScript errors preventing execution

**If you DO see this log:**
- Request is being sent from frontend
- Continue to Step 2

### Step 2: Check Browser Network Tab

1. Open DevTools → Network tab
2. Click Save Menu button
3. Look for request to `/api/vendor/menus/{id}`

**Check these details:**

| What to Check | Expected Value | If Different |
|---------------|----------------|--------------|
| **Method** | PUT | Frontend might be sending wrong method |
| **URL** | `http://localhost:8080/api/vendor/menus/{id}` | Check baseUrl configuration |
| **Status** | 200 OK | Check status code for errors |
| **Headers** | `Authorization: Bearer ...` | Missing token = 401 |
| **Request Payload** | JSON with menu data | Check if body is being sent |
| **Response** | `{"success": true, ...}` | Check for error messages |

### Step 3: Check for CORS Preflight

If you see TWO requests in Network tab:

1. **OPTIONS** `/api/vendor/menus/{id}` - Preflight (should return 204)
2. **PUT** `/api/vendor/menus/{id}` - Actual request (should return 200)

**If OPTIONS fails:**
- CORS middleware might not be working
- Backend might not be running
- URL might be wrong

**Backend should log OPTIONS request:**
```
[OPTIONS] /api/vendor/menus/123 127.0.0.1:54321
[OPTIONS] /api/vendor/menus/123 completed in 1ms - ↪️  204 (Redirect)
```

### Step 4: Check Backend is Running

```bash
# Check if backend container is running
docker ps | grep api

# Expected output:
# delivery_app-api-1   ...   Up   0.0.0.0:8080->8080/tcp
```

**If backend not running:**
```bash
cd /Users/josephsadaka/Repos/delivery_app
docker-compose up -d
```

### Step 5: Check Backend Logs

```bash
# Follow logs in real-time
docker logs -f delivery_app-api-1

# Or check last 100 lines
docker logs --tail 100 delivery_app-api-1
```

**You should see:**
1. OPTIONS preflight request
2. PUT request entry
3. PUT request completion

**Example expected logs:**
```
[OPTIONS] /api/vendor/menus/5 127.0.0.1:54321
[OPTIONS] /api/vendor/menus/5 completed in 1ms - ↪️  204 (Redirect)
[PUT] /api/vendor/menus/5 127.0.0.1:54321
[PUT] /api/vendor/menus/5 completed in 245ms - ✅ 200 (Success)
```

### Step 6: Test with cURL

Verify backend can receive PUT requests:

```bash
# Get a valid JWT token first (copy from browser DevTools → Application → Local Storage)
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test PUT request
curl -v -X PUT http://localhost:8080/api/vendor/menus/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Menu",
    "description": "Testing",
    "menu_config": "{\"version\":\"1.0\",\"categories\":[]}"
  }'
```

**Expected response:**
```json
{
  "success": true,
  "message": "Menu updated successfully",
  "menu": { ... }
}
```

**If cURL works but frontend doesn't:**
- Frontend request format is different
- Frontend token might be invalid/expired
- Frontend baseUrl might be wrong

### Step 7: Check Frontend API Configuration

**File:** `frontend/lib/config/api_config.dart`

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:8080';  // ← Should match backend
  // ...
}
```

**Verify:**
- baseUrl matches backend (should be `http://localhost:8080`)
- No trailing slash
- Port 8080 is correct

## Common Issues and Fixes

### Issue 1: Request Never Sent
**Symptoms:** No logs in frontend console, no network request

**Possible Causes:**
- Save button not calling `_saveMenu()`
- JavaScript error preventing execution
- Menu ID is null

**Debug:**
```dart
// Add at start of _saveMenu()
developer.log('=== SAVE MENU CALLED ===', name: 'MenuBuilderScreen');
developer.log('Menu ID: ${widget.menu.id}', name: 'MenuBuilderScreen');
developer.log('Token present: ${widget.token != null}', name: 'MenuBuilderScreen');
```

### Issue 2: Request Sent But No Response
**Symptoms:** Frontend logs request, but hangs

**Possible Causes:**
- Backend not running
- Wrong URL
- Network/firewall blocking request
- Timeout too short

**Debug:**
```bash
# Check if port 8080 is listening
lsof -i :8080

# Check if you can reach backend
curl http://localhost:8080/health
```

### Issue 3: CORS Error
**Symptoms:** Browser console shows CORS error

**Error Message:**
```
Access to XMLHttpRequest at 'http://localhost:8080/api/vendor/menus/1'
from origin 'http://localhost:55555' has been blocked by CORS policy
```

**Fix:**
Backend CORS middleware should allow all origins (already configured in `middleware.go`)

### Issue 4: 401 Unauthorized
**Symptoms:** Request sent, but returns 401

**Possible Causes:**
- JWT token expired
- Token not in Authorization header
- Token format wrong (should be "Bearer {token}")

**Debug:**
```dart
// Add to http_client_service.dart before making request
developer.log('Full headers: $requestHeaders', name: 'HTTP_CLIENT');
developer.log('URL: $url', name: 'HTTP_CLIENT');
```

### Issue 5: Request Timeout
**Symptoms:** Request hangs for 30 seconds then fails

**Possible Causes:**
- Backend stuck processing request
- Network issue
- Backend panic/crash

**Check:**
```bash
# Check backend logs for panics
docker logs delivery_app-api-1 | grep -i panic

# Check if handler is stuck
docker logs delivery_app-api-1 | grep "PUT.*menu"
```

## Step-by-Step Checklist

Run through this checklist systematically:

- [ ] **Backend running:** `docker ps | grep api` shows container running
- [ ] **Backend healthy:** `curl http://localhost:8080/health` returns 200
- [ ] **Frontend logging:** Browser console shows PUT request log
- [ ] **Network tab:** PUT request appears in DevTools Network tab
- [ ] **Request URL:** Network tab shows `http://localhost:8080/api/vendor/menus/{id}`
- [ ] **Authorization header:** Network tab shows `Authorization: Bearer ...`
- [ ] **Request body:** Network tab shows JSON payload
- [ ] **Status code:** Network tab shows status (200, 401, 400, etc.)
- [ ] **Backend logs:** `docker logs -f delivery_app-api-1` shows PUT request
- [ ] **CORS preflight:** Backend logs show OPTIONS request before PUT

## If Still Not Working

If you've confirmed all the above and still not seeing logs:

### Advanced Debugging

1. **Add verbose logging to backend:**

Edit `backend/middleware.go` line 80:
```go
// Before
log.Printf("[%s] %s %s", r.Method, r.URL.Path, r.RemoteAddr)

// After (more verbose)
log.Printf("========================================")
log.Printf("[%s] %s", r.Method, r.URL.Path)
log.Printf("Headers: %+v", r.Header)
log.Printf("Remote: %s", r.RemoteAddr)
log.Printf("========================================")
```

Rebuild and restart backend.

2. **Add verbose logging to frontend:**

Edit `frontend/lib/services/menu_service.dart` line 61:
```dart
developer.log('========================================', name: 'MenuService');
developer.log('Calling updateMenu', name: 'MenuService');
developer.log('Token: ${token.substring(0, 20)}...', name: 'MenuService');
developer.log('Menu ID: $menuId', name: 'MenuService');
developer.log('Body keys: ${body.keys.toList()}', name: 'MenuService');
developer.log('========================================', name: 'MenuService');

final result = await putObject(...);
```

3. **Test with minimal menu:**

Try updating with minimal data:
```dart
final updatedMenu = widget.menu.copyWith(
  name: 'Test',
  menuConfig: {'version': '1.0', 'categories': []},  // Empty categories
);
```

If minimal works but full menu doesn't, the issue is likely:
- Menu too large (>500KB limit)
- Invalid JSON in menuConfig
- Circular reference in menu data

## Expected Full Flow

When everything works correctly, you should see this sequence:

### Frontend Console:
```
🔵 REQUEST: PUT http://localhost:8080/api/vendor/menus/5
✅ RESPONSE: PUT http://localhost:8080/api/vendor/menus/5 - Status: 200
```

### Browser Network Tab:
```
OPTIONS /api/vendor/menus/5  [204 No Content]
PUT     /api/vendor/menus/5  [200 OK]
```

### Backend Docker Logs:
```
[OPTIONS] /api/vendor/menus/5 127.0.0.1:54321
[OPTIONS] /api/vendor/menus/5 completed in 1ms - ↪️  204 (Redirect)
[PUT] /api/vendor/menus/5 127.0.0.1:54321
[PUT] /api/vendor/menus/5 completed in 245ms - ✅ 200 (Success)
```

### Frontend UI:
```
✓ Snackbar: "Menu saved successfully"
```

---

## Quick Diagnostic Command

Run this while clicking Save:

```bash
# Terminal 1: Watch backend logs
docker logs -f delivery_app-api-1 | grep -E "PUT|OPTIONS"

# Terminal 2: Watch for new connections
lsof -i :8080 -r 1
```

Then click Save and watch for output.

---

**Next Step:** Follow Step 1-7 above and report which step fails or produces unexpected output.
