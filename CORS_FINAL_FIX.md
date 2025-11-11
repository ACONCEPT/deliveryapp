# CORS Final Fix - Complete Solution

## Problem Summary

CORS preflight (OPTIONS) requests are returning **HTTP 500** instead of 200/204, blocking all cross-origin requests from CloudFront to API Gateway.

## Root Cause

**API Gateway HTTP API with Lambda Proxy Integration** has a critical interaction issue:

When you configure CORS at the API Gateway level AND use Lambda proxy integration:
- API Gateway tries to handle OPTIONS
- But with proxy integration, it ALSO forwards OPTIONS to Lambda
- If both try to handle CORS, they conflict
- Result: 500 errors, duplicate/conflicting headers

## The Solution

**Let Lambda handle ALL CORS, including OPTIONS preflight.**

### Why This Works

With Lambda proxy integration:
1. API Gateway forwards ALL requests (including OPTIONS) to Lambda
2. Lambda's `CORSMiddleware` handles CORS headers for all methods
3. Lambda's route definitions include OPTIONS method
4. Lambda returns proper 204 No Content for OPTIONS
5. No conflicts, no duplicate headers

## Changes Required

### 1. API Gateway - Remove CORS Config ✅

**File:** `terraform/infra/api_gateway.tf`

**Before:**
```hcl
cors_configuration {
  allow_credentials = true
  allow_headers     = ["*"]
  allow_methods     = ["*"]
  allow_origins     = ["https://${aws_cloudfront_distribution.frontend.domain_name}"]
  expose_headers    = ["*"]
  max_age           = 86400
}
```

**After:**
```hcl
# CORS is handled by the Lambda application (CORSMiddleware in Go)
# DO NOT configure CORS here - it conflicts with Lambda proxy integration
# The Lambda returns proper CORS headers for all requests including OPTIONS
```

### 2. Lambda - OPTIONS Support ✅

**File:** `backend/cmd/lambda/main.go`

All routes already have OPTIONS:
```go
router.HandleFunc("/api/login", h.Login).Methods("POST", "OPTIONS")
router.HandleFunc("/api/signup", h.Signup).Methods("POST", "OPTIONS")
// ... all other routes
```

### 3. Lambda - CORS Middleware ✅

**File:** `backend/middleware/common.go`

Already correctly configured:
```go
func CORSMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Echo back the Origin header
        origin := r.Header.Get("Origin")
        if origin == "" {
            origin = "*"
        }
        w.Header().Set("Access-Control-Allow-Origin", origin)
        w.Header().Set("Access-Control-Allow-Credentials", "true")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD")
        w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, Authorization, X-CSRF-Token, X-Requested-With, Origin, Access-Control-Request-Method, Access-Control-Request-Headers")
        w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type, Authorization")
        w.Header().Set("Access-Control-Max-Age", "86400")

        // Handle preflight OPTIONS requests
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusNoContent) // 204
            return
        }

        next.ServeHTTP(w, r)
    })
}
```

## Deployment Steps

### Step 1: Build Updated Lambda

The Lambda code already has OPTIONS support and CORS middleware. Rebuild to ensure latest:

```bash
./tools/sh/build-lambda.sh
```

**Expected output:**
```
✓ Created build/lambda-deployment.zip
✓ Created build/lambda-jobs-deployment.zip
```

### Step 2: Deploy with Terraform

This deploys BOTH the infrastructure change (remove API Gateway CORS) AND the Lambda update:

```bash
cd terraform/infra
terraform plan
terraform apply
```

**Expected changes:**
```
Terraform will perform the following actions:

  # aws_apigatewayv2_api.main will be updated in-place
  ~ resource "aws_apigatewayv2_api" "main" {
      - cors_configuration {
          - allow_credentials = true
          - allow_headers     = ["*"]
          - allow_methods     = ["*"]
          - allow_origins     = ["https://..."]
        }
    }

  # aws_lambda_function.backend will be updated in-place
  ~ resource "aws_lambda_function" "backend" {
      ~ last_modified      = "2025-11-11T00:33:07.000+0000" -> (known after apply)
      ~ source_code_hash   = "..." -> "..."
    }

Plan: 0 to add, 2 to change, 0 to destroy.
```

## How It Works After Deployment

### OPTIONS Preflight Flow

```
Browser → OPTIONS /api/login
          Origin: https://d1b8hnq3oepzhd.cloudfront.net
          ↓
     API Gateway
     - NO CORS config (passes through)
     - Forwards to Lambda
          ↓
     Lambda (Go)
     - CORSMiddleware executes
     - Echoes Origin header
     - Returns 204 No Content
     - Headers:
       Access-Control-Allow-Origin: https://d1b8hnq3oepzhd.cloudfront.net
       Access-Control-Allow-Credentials: true
       Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
       Access-Control-Allow-Headers: Accept, Content-Type, ...
          ↓
     API Gateway (passes response through)
          ↓
     Browser (approves, sends actual request)
```

### Actual Request Flow

```
Browser → POST /api/login
          Origin: https://d1b8hnq3oepzhd.cloudfront.net
          ↓
     API Gateway (passes through)
          ↓
     Lambda (Go)
     - CORSMiddleware adds headers
     - LoginHandler executes
     - Returns 200 OK with data
          ↓
     API Gateway (passes through)
          ↓
     Browser (receives response)
```

## Testing After Deployment

### Test 1: Direct OPTIONS Test

```bash
curl -X OPTIONS https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com/api/login \
  -H "Origin: https://d1b8hnq3oepzhd.cloudfront.net" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" \
  -v 2>&1 | grep "< HTTP"
```

**Expected:** `< HTTP/2 204` (not 500!)

### Test 2: Check CORS Headers

```bash
curl -X OPTIONS https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com/api/login \
  -H "Origin: https://d1b8hnq3oepzhd.cloudfront.net" \
  -H "Access-Control-Request-Method: POST" \
  -v 2>&1 | grep -i "access-control"
```

**Expected:**
```
< access-control-allow-origin: https://d1b8hnq3oepzhd.cloudfront.net
< access-control-allow-credentials: true
< access-control-allow-methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
< access-control-allow-headers: Accept, Content-Type, Content-Length, ...
```

### Test 3: Browser Test

1. **Navigate to:** `https://d1b8hnq3oepzhd.cloudfront.net`
2. **Open DevTools:** F12 → Network tab
3. **Try login:** `customer1` / `password123`
4. **Verify:**
   - OPTIONS request: Status 204 ✅
   - POST request: Status 200 ✅
   - No CORS errors in console ✅

## Why This Approach

### Option 1: API Gateway CORS Only ❌
- Doesn't work with Lambda proxy integration
- OPTIONS still forwarded to Lambda
- Causes conflicts

### Option 2: Lambda CORS Only ✅ (Our Solution)
- Works perfectly with proxy integration
- Single source of CORS logic
- No conflicts
- Full control in application code

### Option 3: Both API Gateway and Lambda CORS ❌
- What we had before
- Causes conflicts and 500 errors
- Duplicate/conflicting headers

## Key Insights

1. **Lambda Proxy Integration** means Lambda handles everything
2. **API Gateway CORS** only works with non-proxy integrations
3. **Mixing both** causes conflicts and errors
4. **Best practice:** Let Lambda handle CORS for proxy integration

## Files Changed

| File | Change | Status |
|------|--------|--------|
| `terraform/infra/api_gateway.tf` | Removed cors_configuration block | ✅ Done |
| `backend/cmd/lambda/main.go` | OPTIONS added to routes | ✅ Already done |
| `backend/middleware/common.go` | CORS middleware | ✅ Already correct |

## Summary

| Step | Action | Status |
|------|--------|--------|
| 1 | Remove API Gateway CORS config | ✅ Complete |
| 2 | Ensure Lambda has OPTIONS support | ✅ Complete |
| 3 | Ensure Lambda has CORS middleware | ✅ Complete |
| 4 | Build Lambda | ⏳ Need to run |
| 5 | Deploy with Terraform | ⏳ Need to run |
| 6 | Test CORS | ⏳ After deploy |

## Next Steps

```bash
# 1. Build Lambda
./tools/sh/build-lambda.sh

# 2. Deploy everything
cd terraform/infra
terraform apply

# 3. Test
curl -X OPTIONS https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com/api/login \
  -H "Origin: https://d1b8hnq3oepzhd.cloudfront.net" \
  -H "Access-Control-Request-Method: POST" \
  -v 2>&1 | grep "< HTTP"

# Should see: < HTTP/2 204
```

After this deployment, CORS will work correctly! 🎉
