# API Gateway CORS Configuration Fix

## Issue

Even after adding OPTIONS support to backend routes, CORS preflight was still failing:

```
Access to fetch at 'https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com/api/login'
from origin 'https://d1b8hnq3oepzhd.cloudfront.net' has been blocked by CORS policy:
Response to preflight request doesn't pass access control check: It does not have HTTP ok status.
```

## Root Cause

API Gateway v2 (HTTP API) has its own CORS configuration that was conflicting with the application-level CORS:

**Problem 1: Credentials Mismatch**
- API Gateway: `allow_credentials = false`
- Backend middleware: `Access-Control-Allow-Credentials: true`
- **Result:** Browser rejects the response due to conflicting headers

**Problem 2: Wildcard Origins with Credentials**
- API Gateway: `allow_origins = ["*"]`
- When using `*`, credentials **must** be false (browser security rule)
- Cannot use both `*` origins and `credentials: true`

## Understanding the Issue

When using AWS API Gateway with Lambda proxy integration:

1. **API Gateway handles OPTIONS preflight** (before reaching Lambda)
2. API Gateway's CORS config adds headers to the OPTIONS response
3. If API Gateway CORS conflicts with Lambda CORS, browsers reject the response
4. The Lambda code never even runs for preflight requests

**CORS Header Priority:**
```
Browser → API Gateway (handles OPTIONS) → Lambda (handles actual request)
          ↓
     CORS headers set here (for OPTIONS)
                              ↓
                         CORS headers set here (for POST/GET/etc)
```

Both layers must agree, especially on `allow_credentials`.

## Fix Applied

### File Modified
`terraform/infra/api_gateway.tf`

### Changes Made

**Before:**
```hcl
cors_configuration {
  allow_credentials = false  # ❌ Conflicts with backend
  allow_headers     = ["*"]
  allow_methods     = ["*"]
  allow_origins     = var.cors_allowed_origins  # ["*"]
  expose_headers    = ["*"]
  max_age           = 86400
}
```

**After:**
```hcl
cors_configuration {
  allow_credentials = true  # ✅ Matches backend
  allow_headers     = ["*"]
  allow_methods     = ["*"]
  # ✅ Explicitly allow CloudFront and localhost
  allow_origins     = concat(
    ["https://${aws_cloudfront_distribution.frontend.domain_name}"],
    var.environment == "dev" ? ["http://localhost:*"] : []
  )
  expose_headers    = ["*"]
  max_age           = 86400
}
```

### What Changed

1. **`allow_credentials = true`**
   - Now matches backend middleware
   - Allows cookies and Authorization headers

2. **Explicit Origins**
   - Production: Only allows CloudFront URL
   - Development: Also allows localhost patterns
   - No more wildcard `*` (required for credentials)

3. **Dynamic Configuration**
   - Uses Terraform reference to CloudFront domain
   - Automatically correct even if CloudFront URL changes
   - Environment-aware (dev vs prod)

## Why This Works

### Browser CORS Rules

When `credentials: true` is set:
- ❌ `Access-Control-Allow-Origin: *` is **forbidden**
- ✅ `Access-Control-Allow-Origin: https://d1b8hnq3oepzhd.cloudfront.net` is **allowed**

The browser **requires** an exact origin match when credentials are involved.

### API Gateway Behavior

For HTTP APIs with Lambda proxy integration:
- API Gateway handles OPTIONS preflight automatically
- It uses the `cors_configuration` block to generate headers
- The Lambda is **not invoked** for OPTIONS requests
- For actual requests (POST, GET, etc.), both API Gateway and Lambda headers apply

## Deployment

### Prerequisites
1. Lambda code already updated with OPTIONS support ✅
2. Build script fixed (TMPDIR) ✅
3. Frontend deployed with correct API URL ✅

### Deploy This Fix

```bash
cd terraform/infra
terraform plan  # Review changes
terraform apply
```

**Expected Changes:**
```
Terraform will perform the following actions:

  # aws_apigatewayv2_api.main will be updated in-place
  ~ resource "aws_apigatewayv2_api" "main" {
      ~ cors_configuration {
          ~ allow_credentials = false -> true
          ~ allow_origins     = ["*"] -> ["https://d1b8hnq3oepzhd.cloudfront.net", "http://localhost:*"]
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

### Verification After Deploy

1. **Open Browser DevTools** (F12) → Network tab
2. **Navigate to** `https://d1b8hnq3oepzhd.cloudfront.net`
3. **Try login** with: `customer1` / `password123`
4. **Check OPTIONS request:**
   ```
   Response Headers:
   access-control-allow-origin: https://d1b8hnq3oepzhd.cloudfront.net
   access-control-allow-credentials: true
   access-control-allow-methods: *
   access-control-allow-headers: *
   ```

5. **No CORS errors in console** ✅

## Complete CORS Flow

### OPTIONS Preflight (Handled by API Gateway)
```
Browser → OPTIONS /api/login
          ↓
     API Gateway
     - Checks cors_configuration
     - Returns 200 OK
     - Headers: allow-origin, allow-credentials, allow-methods
          ↓
     Browser (approves)
```

### Actual Request (Handled by Lambda)
```
Browser → POST /api/login
          ↓
     API Gateway (passes through)
          ↓
     Lambda / Go backend
     - CORSMiddleware adds headers
     - Returns 200 OK with data
          ↓
     API Gateway (passes through)
          ↓
     Browser (receives response)
```

## Why Previous Fixes Didn't Work

1. **Backend OPTIONS support** - Good, but OPTIONS never reached backend (API Gateway handles it)
2. **Backend CORS middleware** - Good for actual requests, but not for preflight
3. **Frontend config** - Good, but doesn't affect CORS

The missing piece was **API Gateway CORS configuration**.

## Environment-Specific Behavior

### Development Environment
Allows:
- ✅ `https://d1b8hnq3oepzhd.cloudfront.net` (CloudFront)
- ✅ `http://localhost:*` (local development)

### Production Environment
Allows:
- ✅ Production CloudFront domain only
- ❌ Localhost (not included in production)

This is controlled by:
```hcl
var.environment == "dev" ? ["http://localhost:*"] : []
```

## Troubleshooting

### If CORS still fails after deployment

1. **Check API Gateway was actually updated:**
   ```bash
   aws apigatewayv2 get-api --api-id ugzgutwvt0 --query 'CorsConfiguration'
   ```

2. **Check the exact origin being sent:**
   - Browser DevTools → Network → Request Headers
   - Look for `Origin:` header
   - Must exactly match allowed origin

3. **Clear browser cache:**
   - Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
   - Or use Incognito/Private mode

4. **Check CloudFront URL matches:**
   ```bash
   terraform output cloudfront_url
   # Should match allowed origin in API Gateway
   ```

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| `terraform/infra/api_gateway.tf` | Fixed CORS configuration | 9-20 |

## Summary

| Aspect | Status |
|--------|--------|
| Root cause | ✅ Identified (API Gateway CORS config) |
| Fix applied | ✅ Complete (credentials + explicit origins) |
| Ready to deploy | ✅ Yes (terraform apply) |

The CORS issue was at the API Gateway level, not in the application code. This fix ensures API Gateway and backend CORS settings are aligned.

## Next Steps

1. **Deploy:** `cd terraform/infra && terraform apply`
2. **Wait:** ~30 seconds for API Gateway to update
3. **Test:** Navigate to CloudFront URL and try login
4. **Verify:** Check Network tab for successful OPTIONS + POST requests

After deployment, CORS will work correctly! 🎉
