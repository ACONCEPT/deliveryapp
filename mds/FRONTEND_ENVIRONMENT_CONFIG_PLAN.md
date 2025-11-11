# Frontend Environment Configuration Implementation Plan

## Executive Summary

This document provides a comprehensive implementation plan for configuring the Flutter frontend to support different backend endpoints for development (localhost) and production (AWS API Gateway) environments.

## Current State Analysis

### API Configuration Architecture

#### 1. Current Implementation
The frontend currently uses a centralized configuration approach:

**File: `/frontend/lib/config/api_config.dart`**
```dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String apiPrefix = '/api';
  static String get fullBaseUrl => '$baseUrl$apiPrefix';

  // Endpoint paths
  static const String login = '/auth/login';
  static const String addresses = '/addresses';
  static const String restaurants = '/restaurants';
  // ... other endpoints
}
```

**Key Features:**
- Uses `String.fromEnvironment()` for compile-time configuration
- Defaults to `http://localhost:8080` for local development
- Already supports environment-based configuration via `--dart-define`
- Centralized endpoint definitions

#### 2. HTTP Client Service
**File: `/frontend/lib/services/http_client_service.dart`**
```dart
class HttpClientService {
  static final String baseUrl = ApiConfig.baseUrl;

  // Singleton pattern with automatic token injection
  Future<http.Response> get(String path, {...}) async {
    final url = '$baseUrl$path';
    // ... HTTP request logic
  }
}
```

**Key Features:**
- Singleton pattern for consistent configuration
- Reads baseUrl from ApiConfig
- Automatic Bearer token injection via AuthProvider
- Comprehensive request/response logging

#### 3. Service Layer Architecture
All API services extend `BaseService` or use `HttpClientService`:

**Services Using API:**
- `api_service.dart` - Authentication (login, signup)
- `address_service.dart` - Address CRUD operations
- `menu_service.dart` - Menu management
- `order_service.dart` - Order operations
- `approval_service.dart` - Admin approvals
- `restaurant_service.dart` - Restaurant data
- `customization_template_service.dart` - Menu customizations
- `system_settings_service.dart` - System configuration
- `distance_service.dart` - Distance calculations

**External APIs (Not Affected):**
- `nominatim_service.dart` - Uses OpenStreetMap API (https://nominatim.openstreetmap.org)

#### 4. Current Build Script
**File: `/tools/sh/deploy-frontend.sh`**
```bash
#!/bin/bash
# Step 1: Build Flutter Web App
cd "$FRONTEND_DIR"
flutter build web --release

# Step 2-4: Deploy to S3 and CloudFront
aws s3 sync "$FRONTEND_DIR/build/web/" "s3://$S3_BUCKET/" --delete
aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_ID" --paths "/*"
```

**Current Limitations:**
- No environment-specific configuration
- Hardcodes to default localhost:8080
- No API Gateway URL injection

### Infrastructure Architecture

#### AWS Resources (from Terraform outputs)
```
Backend API:
  - API Gateway HTTP API v2 (cheaper, simpler than REST API)
  - Lambda proxy integration
  - Output: aws_apigatewayv2_api.main.api_endpoint
  - Example: https://abc123def.execute-api.us-east-1.amazonaws.com

Frontend:
  - S3 bucket for static hosting
  - CloudFront distribution
  - Output: cloudfront_url
  - Example: https://d1234567890.cloudfront.net

CORS Configuration:
  - Configured in API Gateway
  - Allow origins: var.cors_allowed_origins (configurable)
```

## Implementation Plan

### Solution Design

We will use **Flutter's `--dart-define` approach** because:
1. It's already implemented in `ApiConfig.baseUrl`
2. Compile-time configuration (more secure than runtime)
3. No additional dependencies required
4. Works perfectly with CI/CD pipelines
5. Type-safe at compile time

### Phase 1: Update Deployment Script

#### File: `/tools/sh/deploy-frontend.sh`

**Changes Required:**
1. Get API Gateway URL from Terraform outputs
2. Pass URL to Flutter build via `--dart-define`
3. Add environment parameter support

**Implementation:**

```bash
#!/bin/bash

# Deploy Frontend Script
# This script builds the Flutter web app and deploys it to S3/CloudFront

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Frontend Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse command-line arguments
ENVIRONMENT="prod"
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --env ENV       Environment to deploy to (default: prod)"
      echo "  --help          Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Deploy to production"
      echo "  $0 --env staging      # Deploy to staging"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo ""

# Get the project root directory (3 levels up from tools/sh/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/infra"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Step 1: Get deployment configuration from Terraform
echo -e "${YELLOW}Step 1: Getting deployment configuration...${NC}"
cd "$TERRAFORM_DIR"

# Get infrastructure outputs
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw frontend_s3_bucket 2>/dev/null || echo "")
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")

# Validate outputs
if [ -z "$API_GATEWAY_URL" ] || [ -z "$S3_BUCKET" ] || [ -z "$CLOUDFRONT_ID" ]; then
    echo -e "${RED}Error: Failed to get Terraform outputs${NC}"
    echo "Please ensure Terraform infrastructure is deployed."
    echo ""
    echo "Run: cd terraform/infra && terraform apply"
    exit 1
fi

echo "API Gateway URL: $API_GATEWAY_URL"
echo "S3 Bucket: $S3_BUCKET"
echo "CloudFront Distribution: $CLOUDFRONT_ID"
echo -e "${GREEN}✓ Configuration retrieved${NC}"
echo ""

# Step 2: Build Flutter Web App with environment-specific configuration
echo -e "${YELLOW}Step 2: Building Flutter web application...${NC}"
echo "Backend API URL: $API_GATEWAY_URL"
cd "$FRONTEND_DIR"

# Build with environment configuration
flutter build web --release \
  --dart-define=API_BASE_URL="$API_GATEWAY_URL" \
  --dart-define=ENVIRONMENT="$ENVIRONMENT"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Flutter build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter build completed${NC}"
echo ""

# Step 3: Upload files to S3
echo -e "${YELLOW}Step 3: Uploading files to S3...${NC}"
aws s3 sync "$FRONTEND_DIR/build/web/" "s3://$S3_BUCKET/" --delete

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: S3 upload failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Files uploaded to S3${NC}"
echo ""

# Step 4: Invalidate CloudFront cache
echo -e "${YELLOW}Step 4: Invalidating CloudFront cache...${NC}"
INVALIDATION_OUTPUT=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_ID" --paths "/*")

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: CloudFront invalidation failed${NC}"
    exit 1
fi

INVALIDATION_ID=$(echo "$INVALIDATION_OUTPUT" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
echo "Invalidation ID: $INVALIDATION_ID"
echo -e "${GREEN}✓ CloudFront invalidation created${NC}"
echo ""

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration:"
echo -e "  Environment:     ${BLUE}$ENVIRONMENT${NC}"
echo -e "  Backend API:     ${BLUE}$API_GATEWAY_URL${NC}"
echo -e "  Frontend URL:    ${BLUE}$CLOUDFRONT_URL${NC}"
echo ""
echo -e "${YELLOW}Note: CloudFront invalidation may take a few minutes to complete.${NC}"
echo ""
```

**Key Changes:**
- Extracts `API_GATEWAY_URL` from Terraform outputs
- Passes to Flutter build via `--dart-define=API_BASE_URL`
- Adds environment parameter support
- Comprehensive error handling
- Clear output messaging

### Phase 2: Enhance ApiConfig (Optional Improvements)

#### File: `/frontend/lib/config/api_config.dart`

**Optional Enhancements:**

```dart
/// API Configuration
/// Centralizes all API-related configuration including base URLs and endpoints
class ApiConfig {
  /// Base URL for the API server
  /// Can be overridden via environment variable API_BASE_URL
  ///
  /// Development: http://localhost:8080
  /// Production: https://your-api-gateway-url.execute-api.region.amazonaws.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Current environment (dev, staging, prod)
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  /// API version prefix
  static const String apiPrefix = '/api';

  /// Full base URL with API prefix
  static String get fullBaseUrl => '$baseUrl$apiPrefix';

  /// Check if running in production
  static bool get isProduction => environment == 'prod';

  /// Check if running in development
  static bool get isDevelopment => environment == 'dev';

  /// API Endpoints
  static const String login = '/auth/login';
  static const String addresses = '/addresses';
  static const String restaurants = '/restaurants';
  static const String menu = '/menu';
  static const String menuItems = '/menu-items';
  static const String orders = '/orders';
  static const String approvals = '/approvals';
  static const String systemSettings = '/system-settings';
  static const String distance = '/distance';

  /// HTTP request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Maximum number of retry attempts for failed requests
  static const int maxRetries = 3;

  /// Retry delay multiplier for exponential backoff
  static const Duration retryBaseDelay = Duration(seconds: 1);

  /// Log current configuration (useful for debugging)
  static void logConfiguration() {
    print('====================================');
    print('API Configuration');
    print('====================================');
    print('Environment: $environment');
    print('Base URL: $baseUrl');
    print('Full URL: $fullBaseUrl');
    print('Request Timeout: ${requestTimeout.inSeconds}s');
    print('Max Retries: $maxRetries');
    print('====================================');
  }
}
```

**Benefits:**
- Adds environment awareness
- Helper methods for environment checks
- Configuration logging for debugging
- Better documentation

### Phase 3: Update Main App Initialization

#### File: `/frontend/lib/main.dart`

**Add configuration logging on startup:**

```dart
void main() async {
  print('🚀 main() called - Starting app initialization');

  try {
    print('  Initializing WidgetsFlutterBinding...');
    WidgetsFlutterBinding.ensureInitialized();
    print('  ✅ WidgetsFlutterBinding initialized');

    // Log API configuration
    print('  Logging API configuration...');
    ApiConfig.logConfiguration();  // ADD THIS LINE
    print('  ✅ API configuration logged');

    // Initialize auth provider and restore session
    print('  Creating AuthProvider...');
    final authProvider = AuthProvider();
    // ... rest of initialization
```

**Benefits:**
- Immediate visibility of configuration on app start
- Helps debug environment issues
- Confirms correct URL is being used

### Phase 4: Local Development Script

#### New File: `/tools/sh/run-local-frontend.sh`

Create a helper script for local development:

```bash
#!/bin/bash

# Run Frontend Locally
# This script runs the Flutter web app in development mode

set -e

echo "=========================================="
echo "Starting Flutter Frontend (Development)"
echo "=========================================="
echo ""

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Check if backend is running
echo "Checking if backend is running on localhost:8080..."
if curl -s -f -o /dev/null http://localhost:8080/health; then
    echo "✓ Backend is running"
else
    echo "⚠️  Warning: Backend not detected on localhost:8080"
    echo "   Make sure to start the backend server first:"
    echo "   cd backend && go run main.go"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Starting Flutter web server..."
echo "Backend API: http://localhost:8080"
echo "Frontend will be available at: http://localhost:PORT"
echo ""

cd "$FRONTEND_DIR"

# Run with development configuration (defaults to localhost:8080)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev
```

**Benefits:**
- Easy local development startup
- Verifies backend is running
- Explicit configuration values
- Documentation for developers

### Phase 5: Testing Different Environments

#### Create Test Configuration Script

**New File: `/tools/sh/test-api-config.sh`**

```bash
#!/bin/bash

# Test API Configuration
# This script builds the frontend with different configurations to verify setup

set -e

echo "=========================================="
echo "API Configuration Test"
echo "=========================================="
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

cd "$FRONTEND_DIR"

# Test 1: Default configuration (localhost)
echo "Test 1: Building with default configuration (localhost)..."
flutter build web \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev

if [ $? -eq 0 ]; then
    echo "✓ Default build successful"

    # Check the compiled JavaScript for the API URL
    if grep -q "localhost:8080" build/web/main.dart.js; then
        echo "✓ localhost:8080 found in compiled output"
    else
        echo "✗ localhost:8080 NOT found in compiled output"
    fi
else
    echo "✗ Default build failed"
    exit 1
fi

echo ""

# Test 2: Production-like configuration
echo "Test 2: Building with production-like configuration..."
flutter build web \
  --dart-define=API_BASE_URL=https://example.execute-api.us-east-1.amazonaws.com \
  --dart-define=ENVIRONMENT=prod

if [ $? -eq 0 ]; then
    echo "✓ Production build successful"

    # Check the compiled JavaScript for the API URL
    if grep -q "example.execute-api.us-east-1.amazonaws.com" build/web/main.dart.js; then
        echo "✓ Production URL found in compiled output"
    else
        echo "✗ Production URL NOT found in compiled output"
    fi
else
    echo "✗ Production build failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
```

**Benefits:**
- Verifies configuration works correctly
- Tests both local and production builds
- Confirms URLs are properly embedded

### Phase 6: Documentation Updates

#### Update Frontend README

**File: `/frontend/README.md`**

Create or update with:

```markdown
# Delivery App - Frontend

Flutter web application for the multi-user delivery platform.

## Architecture

### API Configuration

The frontend uses compile-time configuration for backend endpoints via `--dart-define`:

- **Development**: `http://localhost:8080` (default)
- **Production**: AWS API Gateway URL (configured via Terraform)

Configuration is centralized in `/lib/config/api_config.dart`.

## Local Development

### Prerequisites

1. Flutter SDK (>=3.0.0)
2. Chrome browser
3. Backend server running on `localhost:8080`

### Running Locally

```bash
# Option 1: Use the helper script
./tools/sh/run-local-frontend.sh

# Option 2: Run directly
cd frontend
flutter run -d chrome
```

The app will automatically use `http://localhost:8080` as the backend URL.

### Manual Configuration

To override the backend URL:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev
```

## Building

### Development Build

```bash
cd frontend
flutter build web \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=ENVIRONMENT=dev
```

### Production Build

Production builds are handled by the deployment script:

```bash
./tools/sh/deploy-frontend.sh
```

This script:
1. Retrieves API Gateway URL from Terraform
2. Builds Flutter app with production configuration
3. Deploys to S3
4. Invalidates CloudFront cache

## Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `API_BASE_URL` | Backend API base URL | `http://localhost:8080` | `https://abc123.execute-api.us-east-1.amazonaws.com` |
| `ENVIRONMENT` | Environment name | `dev` | `prod`, `staging` |

## API Services

All API calls go through `HttpClientService`, which:
- Reads configuration from `ApiConfig`
- Automatically adds Bearer token authentication
- Provides comprehensive request/response logging
- Handles 401 unauthorized responses

### Available Services

- `api_service.dart` - Authentication
- `address_service.dart` - Address CRUD
- `menu_service.dart` - Menu management
- `order_service.dart` - Order operations
- `approval_service.dart` - Admin approvals
- `restaurant_service.dart` - Restaurant data
- `system_settings_service.dart` - System settings

## Deployment

### Automated Deployment

Use the deployment script:

```bash
./tools/sh/deploy-frontend.sh
```

### Manual Deployment

1. Get infrastructure outputs:
```bash
cd terraform/infra
export API_URL=$(terraform output -raw api_gateway_url)
export S3_BUCKET=$(terraform output -raw frontend_s3_bucket)
export CF_ID=$(terraform output -raw cloudfront_distribution_id)
```

2. Build with production config:
```bash
cd frontend
flutter build web --release \
  --dart-define=API_BASE_URL="$API_URL" \
  --dart-define=ENVIRONMENT=prod
```

3. Deploy to S3:
```bash
aws s3 sync build/web/ "s3://$S3_BUCKET/" --delete
```

4. Invalidate CloudFront:
```bash
aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*"
```

## Testing

### Test API Configuration

```bash
./tools/sh/test-api-config.sh
```

This verifies that the configuration system works correctly for both local and production builds.

## Troubleshooting

### Issue: API calls failing in production

Check that the API Gateway URL is correct:
1. View Terraform outputs: `cd terraform/infra && terraform output`
2. Check CloudWatch logs for the API Lambda
3. Verify CORS is configured correctly in API Gateway

### Issue: 401 Unauthorized errors

The app automatically clears authentication on 401 responses. User will be redirected to login.

### Issue: Can't connect to localhost backend

Ensure the backend is running:
```bash
cd backend
go run main.go
```

Backend should be available at `http://localhost:8080/health`
```

## Implementation Checklist

### Required Changes

- [ ] **Update deployment script** (`/tools/sh/deploy-frontend.sh`)
  - Add Terraform output extraction for API Gateway URL
  - Add `--dart-define=API_BASE_URL` to Flutter build command
  - Add error handling for missing Terraform outputs
  - Test deployment script

- [ ] **Create local development script** (`/tools/sh/run-local-frontend.sh`)
  - Backend health check
  - Explicit localhost configuration
  - User-friendly error messages

- [ ] **Create test script** (`/tools/sh/test-api-config.sh`)
  - Test default configuration
  - Test production configuration
  - Verify URLs in compiled output

- [ ] **Update ApiConfig** (`/frontend/lib/config/api_config.dart`) [OPTIONAL]
  - Add environment constant
  - Add helper methods (isProduction, isDevelopment)
  - Add logConfiguration() method

- [ ] **Update main.dart** (`/frontend/lib/main.dart`)
  - Add ApiConfig.logConfiguration() call
  - Verify configuration on startup

- [ ] **Create/update documentation** (`/frontend/README.md`)
  - API configuration explanation
  - Local development instructions
  - Deployment instructions
  - Troubleshooting guide

- [ ] **Make scripts executable**
  ```bash
  chmod +x tools/sh/deploy-frontend.sh
  chmod +x tools/sh/run-local-frontend.sh
  chmod +x tools/sh/test-api-config.sh
  ```

### Testing Checklist

- [ ] **Local Development Testing**
  - [ ] Run backend on localhost:8080
  - [ ] Run frontend with default config
  - [ ] Verify login works
  - [ ] Verify API calls succeed
  - [ ] Check browser console for API configuration log

- [ ] **Production Build Testing**
  - [ ] Deploy Terraform infrastructure (if not already deployed)
  - [ ] Run deployment script
  - [ ] Verify build completes successfully
  - [ ] Check S3 bucket has files
  - [ ] Access CloudFront URL
  - [ ] Verify API calls go to API Gateway (not localhost)
  - [ ] Test login and basic operations

- [ ] **Configuration Testing**
  - [ ] Run test-api-config.sh script
  - [ ] Verify localhost URL in dev build
  - [ ] Verify API Gateway URL in prod build
  - [ ] Test with different API Gateway URLs

- [ ] **CORS Testing**
  - [ ] Verify CloudFront URL is in API Gateway CORS allowed origins
  - [ ] Test API calls from production frontend
  - [ ] Check browser console for CORS errors

## Security Considerations

### Best Practices

1. **No Sensitive Data in Frontend**
   - API URLs are public (visible in JavaScript)
   - Never include API keys or secrets in frontend code
   - Authentication tokens are stored securely in `flutter_secure_storage`

2. **CORS Configuration**
   - Ensure API Gateway CORS includes CloudFront URL
   - Update Terraform `cors_allowed_origins` variable if needed
   - Test CORS in production after deployment

3. **HTTPS Only in Production**
   - CloudFront automatically uses HTTPS
   - API Gateway uses HTTPS
   - Never use HTTP in production

4. **Token Security**
   - Bearer tokens are automatically added by HttpClientService
   - Tokens stored in secure storage (encrypted on device)
   - 401 responses automatically clear tokens and redirect to login

## Alternative Approaches Considered

### 1. Runtime Configuration (Rejected)

**Approach:** Fetch configuration from a JSON file at runtime
```dart
// config.json in web root
{
  "apiUrl": "https://api.example.com"
}

// Load at runtime
Future<void> loadConfig() async {
  final response = await http.get('/config.json');
  final config = json.decode(response.body);
  // Use config...
}
```

**Pros:**
- Can change URL without rebuilding
- Single build for multiple environments

**Cons:**
- Additional HTTP request on startup
- Configuration not type-checked
- More complex error handling
- Security risk (config file could be modified)

**Why Rejected:** Compile-time configuration is more secure and performant.

### 2. Environment Files (.env) (Rejected)

**Approach:** Use `.env` files with a package like `flutter_dotenv`
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  final apiUrl = dotenv.env['API_URL'];
}
```

**Pros:**
- Familiar pattern from other frameworks
- Easy to switch environments locally

**Cons:**
- Additional dependency
- Requires runtime loading
- Environment files in source control (bad practice)
- Not suitable for CI/CD

**Why Rejected:** `--dart-define` is the Flutter-native solution.

### 3. Flutter Flavors (Rejected for Now)

**Approach:** Use Flutter flavors for environment configuration
```dart
// Define flavors in android/build.gradle and ios/Runner.xcconfig
// Access via BuildConfig or preprocessor macros
```

**Pros:**
- Proper Android/iOS flavor support
- Can have different app icons/names per environment
- Native platform integration

**Cons:**
- Much more complex setup
- Requires Android/iOS configuration (we're web-only currently)
- Overkill for just changing API URL
- More files to maintain

**Why Rejected:** Too complex for current needs. `--dart-define` is sufficient.

## Cost Considerations

### Development vs Production

**Development (Localhost):**
- Cost: $0
- No AWS resources consumed
- Full functionality for testing

**Production (AWS):**
- API Gateway HTTP API: ~$1 per million requests
- Lambda: Pay per invocation and compute time
- S3: ~$0.023 per GB storage
- CloudFront: ~$0.085 per GB transfer
- RDS: Fixed cost (~$30-100/month for db.t3.micro)

**Recommendation:** Use localhost for all development and testing. Only deploy to AWS for demos, staging, and production use.

## Monitoring & Debugging

### Production Debugging

1. **Check API Configuration:**
   - Open browser DevTools console
   - Look for "API Configuration" log on app startup
   - Verify correct URL is being used

2. **Check API Gateway Logs:**
   ```bash
   aws logs tail /aws/apigateway/delivery-app-prod --follow
   ```

3. **Check Lambda Logs:**
   ```bash
   aws logs tail /aws/lambda/delivery-app-backend-prod --follow
   ```

4. **Check CORS Issues:**
   - Open browser Network tab
   - Look for failed preflight OPTIONS requests
   - Check for "CORS" errors in console

5. **Verify Infrastructure:**
   ```bash
   cd terraform/infra
   terraform output
   ```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| API calls timeout | API Gateway URL incorrect | Check Terraform outputs |
| CORS errors | CloudFront URL not in allowed origins | Update Terraform `cors_allowed_origins` |
| 401 errors | Token expired or invalid | User will auto-logout, re-login needed |
| 404 errors | Endpoint path incorrect | Check ApiConfig endpoint constants |
| Blank page after deploy | CloudFront cache not invalidated | Run invalidation command |

## Summary

### What We're Doing

1. Using Flutter's built-in `--dart-define` for configuration
2. Passing API Gateway URL from Terraform to Flutter build
3. Keeping localhost as default for development
4. Creating helper scripts for common tasks

### What Doesn't Change

1. ApiConfig already supports environment variables
2. HttpClientService already uses ApiConfig
3. All service classes already use HttpClientService
4. No code changes to existing services needed

### What's New

1. Deployment script extracts API Gateway URL
2. Build command includes `--dart-define`
3. Helper scripts for local development
4. Comprehensive documentation

### Time Estimate

- Script updates: 30 minutes
- Testing: 1 hour
- Documentation: 30 minutes
- **Total: 2 hours**

### Risk Level

**Low Risk**
- Existing code already supports this pattern
- Changes are additive (no breaking changes)
- Easy to rollback if issues occur
- Can test thoroughly before production deployment

## Next Steps

1. Review this implementation plan
2. Make script updates
3. Test locally with both configurations
4. Deploy to production
5. Monitor for any issues
6. Update documentation as needed

## Questions?

For questions or issues:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Verify Terraform outputs
4. Check browser DevTools console
