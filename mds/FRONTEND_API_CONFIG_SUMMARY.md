# Frontend API Configuration - Quick Summary

## Current State

The Flutter frontend **already supports** environment-based API configuration using `--dart-define`. The implementation is complete in the codebase, but the deployment script needs updating.

### Existing Implementation

**File: `/frontend/lib/config/api_config.dart`**
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
```

**Status:** ✅ Already implemented and working

## What Needs to Change

Only the **deployment script** needs updating to pass the production API Gateway URL.

### One File to Modify

**File: `/tools/sh/deploy-frontend.sh`**

**Current:**
```bash
flutter build web --release
```

**Updated:**
```bash
# Get API Gateway URL from Terraform
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)

# Build with production configuration
flutter build web --release \
  --dart-define=API_BASE_URL="$API_GATEWAY_URL" \
  --dart-define=ENVIRONMENT="prod"
```

## Implementation Steps

1. **Update deployment script** (30 minutes)
   - Extract API Gateway URL from Terraform outputs
   - Pass to Flutter build via `--dart-define`
   - Add error handling

2. **Test locally** (30 minutes)
   - Build with localhost URL
   - Verify app works

3. **Test production** (30 minutes)
   - Deploy to AWS
   - Verify API Gateway URL is used
   - Test login and API calls

**Total Time: ~2 hours**

## Development vs Production

| Environment | API URL | Configuration |
|-------------|---------|---------------|
| **Development** | `http://localhost:8080` | Default (no flags needed) |
| **Production** | AWS API Gateway | Set via deployment script |

### Local Development (No Changes Needed)

```bash
# Just run normally - defaults to localhost:8080
flutter run -d chrome
```

### Production Deployment (Script Updated)

```bash
# Script automatically gets URL from Terraform
./tools/sh/deploy-frontend.sh
```

## Files Overview

### Files That Work as-is
- ✅ `/frontend/lib/config/api_config.dart` - Already supports environment variables
- ✅ `/frontend/lib/services/http_client_service.dart` - Uses ApiConfig
- ✅ All service classes - Use HttpClientService
- ✅ `/frontend/lib/services/nominatim_service.dart` - External API (not affected)

### Files to Modify
- 🔧 `/tools/sh/deploy-frontend.sh` - Add Terraform output extraction

### Files to Create (Optional)
- 📄 `/tools/sh/run-local-frontend.sh` - Helper for local dev
- 📄 `/tools/sh/test-api-config.sh` - Verify configuration works
- 📄 `/frontend/README.md` - Documentation

## Infrastructure Details

### AWS Resources
```
Backend API:  https://[id].execute-api.[region].amazonaws.com
Frontend:     https://[id].cloudfront.net
```

### Terraform Outputs
```bash
cd terraform/infra
terraform output api_gateway_url        # Backend API
terraform output cloudfront_url         # Frontend URL
terraform output frontend_s3_bucket     # S3 bucket name
```

## Testing Plan

1. **Local Test**
   ```bash
   cd frontend
   flutter run -d chrome
   # Should use localhost:8080
   ```

2. **Production Test**
   ```bash
   ./tools/sh/deploy-frontend.sh
   # Should use API Gateway URL
   ```

3. **Verify Configuration**
   - Open browser DevTools console
   - Check for "API Configuration" log
   - Verify correct URL is shown

## Security Notes

- ✅ API URLs are public (visible in compiled JavaScript) - this is normal
- ✅ No API keys or secrets in frontend code
- ✅ Bearer tokens stored securely via flutter_secure_storage
- ✅ HTTPS enforced in production (CloudFront + API Gateway)
- ✅ CORS configured in API Gateway

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| API calls go to localhost in production | Deployment script not passing `--dart-define` |
| CORS errors in production | Add CloudFront URL to API Gateway CORS config |
| Blank page after deployment | Invalidate CloudFront cache |
| 401 errors | User needs to re-login (token expired) |

## Why This Approach?

### Chosen: `--dart-define` (Compile-time)
- ✅ Already implemented in codebase
- ✅ No additional dependencies
- ✅ Type-safe at compile time
- ✅ Flutter-native solution
- ✅ Works perfectly with CI/CD

### Not Chosen: Runtime Configuration
- ❌ Requires additional HTTP request on startup
- ❌ Not type-checked
- ❌ Security concerns

### Not Chosen: Flutter Flavors
- ❌ Too complex for just changing API URL
- ❌ Requires Android/iOS config (we're web-only)

## Quick Reference

### Development Commands
```bash
# Run locally (uses localhost:8080 by default)
flutter run -d chrome

# Run with explicit configuration
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080
```

### Production Commands
```bash
# Deploy to production (script handles everything)
./tools/sh/deploy-frontend.sh

# Manual build with production config
flutter build web --release \
  --dart-define=API_BASE_URL=https://your-api-gateway-url.amazonaws.com
```

### Debugging Commands
```bash
# View Terraform outputs
cd terraform/infra && terraform output

# Check API Gateway logs
aws logs tail /aws/apigateway/delivery-app-prod --follow

# Check Lambda logs
aws logs tail /aws/lambda/delivery-app-backend-prod --follow
```

## Summary

**Bottom Line:** The frontend is already set up correctly. We just need to update the deployment script to pass the API Gateway URL when building for production. Everything else works as-is.

**Risk Level:** Low - additive changes only, no breaking changes

**Implementation Time:** ~2 hours including testing

**Files Modified:** 1 file (`deploy-frontend.sh`)

**Files Created:** 2-3 optional helper scripts and documentation

For detailed implementation instructions, see: `/mds/FRONTEND_ENVIRONMENT_CONFIG_PLAN.md`
