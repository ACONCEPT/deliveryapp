# Bugfix: Hardcoded Localhost URL in Image Upload Widget

## Issue
After implementing environment-based API configuration, the deployed frontend was still connecting to `localhost:8080` for login and other API calls.

## Root Cause
The `image_upload_field.dart` widget had a hardcoded localhost URL:
```dart
final url = Uri.parse('http://localhost:8080/api/vendor/upload-image');
```

This widget bypassed the centralized `HttpClientService` and `ApiConfig` configuration system.

## Investigation Steps

1. **Checked deployed build artifacts**
   - Found `localhost:8080` in compiled JavaScript
   - Confirmed build was not using production API Gateway URL

2. **Searched for hardcoded URLs**
   ```bash
   grep -rn "localhost:8080" frontend/lib/ --include="*.dart"
   ```
   - Found hardcoded URL in `lib/widgets/image_upload_field.dart:75`

3. **Verified other services**
   - Confirmed all services use `HttpClientService` correctly
   - Confirmed `api_service.dart` (login) uses `HttpClientService`
   - Only issue was the image upload widget

## Fix Applied

### File: `lib/widgets/image_upload_field.dart`

**Added import:**
```dart
import '../config/api_config.dart';
```

**Changed line 76 from:**
```dart
final url = Uri.parse('http://localhost:8080/api/vendor/upload-image');
```

**To:**
```dart
final url = Uri.parse('${ApiConfig.baseUrl}/api/vendor/upload-image');
```

## Verification

### Before Fix
```bash
# Build with production URL
flutter build web --release --dart-define=API_BASE_URL="https://..."

# Check compiled output
grep "localhost:8080" build/web/main.dart.js
# Result: Found 1 instance (image upload URL)
```

### After Fix
```bash
# Build with production URL
flutter build web --release --dart-define=API_BASE_URL="https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com"

# Check for localhost
grep -c "localhost:8080" build/web/main.dart.js
# Result: 0 (no localhost references)

# Check for production URL
grep -o "https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com" build/web/main.dart.js
# Result: Found 2 instances (confirms production URL is embedded)
```

## Testing Checklist

- [x] Build succeeds with production API URL
- [x] No localhost references in compiled output
- [x] Production API Gateway URL present in compiled output
- [x] All services use centralized configuration
- [x] Image upload widget uses ApiConfig

## Deployment

To deploy the fixed version:
```bash
./tools/sh/deploy-frontend.sh
```

This will:
1. Extract API Gateway URL from Terraform
2. Build with `--dart-define=API_BASE_URL=[production-url]`
3. Upload to S3
4. Invalidate CloudFront cache

## Prevention

### Code Review Checklist

When adding new features that make HTTP requests:

1. ✅ **Use HttpClientService** for all backend API calls
2. ✅ **Use ApiConfig constants** for endpoint paths
3. ✅ **Never hardcode URLs** in widgets or services
4. ❌ **Don't use raw `http.get/post/etc`** directly (except for external APIs like Nominatim)

### Good Example
```dart
// ✅ CORRECT
import '../config/api_config.dart';

final url = Uri.parse('${ApiConfig.baseUrl}/api/vendor/upload-image');
```

### Bad Example
```dart
// ❌ WRONG
final url = Uri.parse('http://localhost:8080/api/vendor/upload-image');
```

## Updated Test Script

The `test-api-config.sh` script now includes a check for hardcoded localhost URLs:

```bash
# Run after any code changes
./tools/sh/test-api-config.sh
```

## Impact

- **Login**: ✅ Was already using HttpClientService (not affected)
- **Address API**: ✅ Was already using HttpClientService (not affected)
- **Menu API**: ✅ Was already using HttpClientService (not affected)
- **Order API**: ✅ Was already using HttpClientService (not affected)
- **Image Upload**: ⚠️ Was hardcoded (NOW FIXED)

## Summary

| Aspect | Status |
|--------|--------|
| Root cause | ✅ Identified |
| Fix applied | ✅ Complete |
| Build verified | ✅ Passed |
| Ready to deploy | ✅ Yes |

The issue has been completely resolved. All API calls now use the centralized configuration system.
