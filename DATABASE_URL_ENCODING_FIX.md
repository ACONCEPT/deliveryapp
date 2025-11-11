# DATABASE_URL Special Characters Fix

## Issue

Lambda was failing to initialize with error:
```
Failed to initialize database: failed to connect to database:
parse "postgres://delivery_user:6)&jSSgB_RlZi$0%*M&})6m[)i-6]HHu@...":
net/url: invalid userinfo
```

## Root Cause

The database password `6)&jSSgB_RlZi$0%*M&})6m[)i-6]HHu` contains special characters that are reserved in URLs:
- `&` - URL parameter separator
- `$` - Often used in shell/URL contexts
- `%` - URL encoding prefix
- `[` and `]` - Reserved characters
- `)` - Reserved character

When these characters appear unencoded in a URL, the Go `net/url` parser fails because it interprets them as URL syntax rather than part of the password.

## The Fix

Use Terraform's `urlencode()` function to properly encode the password before constructing the DATABASE_URL.

### Files Modified

1. **terraform/infra/lambda.tf** - Main backend Lambda
2. **terraform/infra/scheduled_jobs.tf** - All 4 job Lambdas

### Changes Made

**Before:**
```hcl
DATABASE_URL = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
```

**After:**
```hcl
DATABASE_URL = "postgres://${var.db_username}:${urlencode(var.db_password)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
```

### What `urlencode()` Does

Converts special characters to their percent-encoded equivalents:
- `&` → `%26`
- `$` → `%24`
- `%` → `%25`
- `[` → `%5B`
- `]` → `%5D`
- `)` → `%29`

So the password becomes:
```
6)&jSSgB_RlZi$0%*M&})6m[)i-6]HHu
↓
6%29%26jSSgB_RlZi%240%25*M%26%7D%296m%5B%29i-6%5DHHu
```

## Files Updated

| File | Locations | Description |
|------|-----------|-------------|
| `terraform/infra/lambda.tf` | Line 147 | Main backend API Lambda |
| `terraform/infra/scheduled_jobs.tf` | Lines 94, 136, 178, 220 | All 4 job Lambdas |

## Deployment

This requires Terraform apply to update the Lambda environment variables:

```bash
cd terraform/infra
terraform apply
```

**Expected changes:**
```
Terraform will perform the following actions:

  # aws_lambda_function.backend will be updated in-place
  ~ resource "aws_lambda_function" "backend" {
      ~ environment {
          ~ variables = {
              ~ DATABASE_URL = "postgres://delivery_user:6)&jSSgB...@..."
                            -> "postgres://delivery_user:6%29%26jSSgB...@..."
            }
        }
    }

Plan: 0 to add, 5 to change, 0 to destroy.
(5 changes: 1 backend + 4 job Lambdas)
```

## Why This Happened

1. **Random password generated** by Terraform with special characters
2. **Directly interpolated** into URL string without encoding
3. **Go URL parser** strictly validates URL syntax
4. **Special characters** break URL parsing

## Prevention

Always use `urlencode()` when embedding passwords or user input in URLs:

```hcl
# ✅ CORRECT
url = "postgres://user:${urlencode(password)}@host/db"

# ❌ WRONG
url = "postgres://user:${password}@host/db"
```

## Testing After Deployment

### Test Lambda Connection

```bash
# Trigger a request to test database connection
curl -X OPTIONS https://ugzgutwvt0.execute-api.us-east-1.amazonaws.com/api/login \
  -H "Origin: https://d1b8hnq3oepzhd.cloudfront.net" \
  -H "Access-Control-Request-Method: POST"
```

### Check Logs

```bash
aws logs tail /aws/lambda/delivery-app-backend-dev --region us-east-1 --since 1m
```

**Should see:**
```
# No more "invalid userinfo" errors
# Should see successful database connection
```

## Summary

| Aspect | Status |
|--------|--------|
| Root cause | ✅ Identified (unencoded special chars) |
| Fix applied | ✅ Complete (urlencode all DATABASE_URLs) |
| Ready to deploy | ✅ Yes (terraform apply) |

The database connection will work after Terraform applies the encoded DATABASE_URL to all Lambdas.
