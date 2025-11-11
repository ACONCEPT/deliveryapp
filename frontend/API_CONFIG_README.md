# Frontend API Configuration

This document explains how the Flutter frontend is configured to connect to different backend environments (local development vs production).

## Overview

The frontend supports environment-based API configuration using Flutter's `--dart-define` compile-time constants. This allows the same codebase to connect to:
- **Local backend** during development (http://localhost:8080)
- **Production API Gateway** when deployed (https://[api-gateway-url])

## Architecture

### Configuration Files

1. **lib/config/api_config.dart**
   - Defines `API_BASE_URL` using `String.fromEnvironment()`
   - Defaults to `http://localhost:8080` for local development
   - Can be overridden at build time with `--dart-define`

2. **lib/services/http_client_service.dart**
   - Singleton HTTP client that reads from `ApiConfig.baseUrl`
   - All API services use this client for consistent configuration

### How It Works

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
```

The `String.fromEnvironment()` reads compile-time constants passed via `--dart-define`. If not provided, it uses the default localhost URL.

## Usage

### Local Development

**Option 1: Default configuration (simplest)**
```bash
cd frontend
flutter run -d chrome
# Automatically uses http://localhost:8080
```

**Option 2: Custom local backend**
```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

**Option 3: Using helper script**
```bash
./tools/sh/run-local-frontend.sh
# Or with custom URL:
./tools/sh/run-local-frontend.sh http://localhost:3000
```

### Production Deployment

The deployment script automatically extracts the API Gateway URL from Terraform and passes it to Flutter:

```bash
./tools/sh/deploy-frontend.sh
```

This script:
1. Retrieves API Gateway URL from Terraform outputs
2. Builds Flutter web with `--dart-define=API_BASE_URL=[api-gateway-url]`
3. Uploads to S3
4. Invalidates CloudFront cache

## File Structure

```
frontend/
├── lib/
│   ├── config/
│   │   └── api_config.dart          # API configuration with environment variable
│   └── services/
│       ├── http_client_service.dart # HTTP client using ApiConfig
│       ├── address_service.dart     # Uses HttpClientService
│       ├── menu_service.dart        # Uses HttpClientService
│       └── order_service.dart       # Uses HttpClientService
tools/sh/
├── deploy-frontend.sh               # Production deployment (extracts API URL from Terraform)
├── run-local-frontend.sh            # Local development helper
└── test-api-config.sh               # Verify configuration is correct
```

## Testing Configuration

Run the configuration test script to verify everything is set up correctly:

```bash
./tools/sh/test-api-config.sh
```

This validates:
- ✓ ApiConfig file exists
- ✓ Environment variable configuration is correct
- ✓ Default backend URL is localhost
- ✓ HttpClientService uses ApiConfig
- ✓ Build succeeds with custom API URL
- ✓ Terraform outputs include API Gateway URL
- ✓ Deployment script passes API configuration

## Environment Details

### Development Environment
```
Frontend (Flutter) → http://localhost:8080/api/* → Go Backend → PostgreSQL
```

### Production Environment
```
Frontend (CloudFront) → https://[api-gateway].execute-api.us-east-1.amazonaws.com/api/*
    → Lambda (Go) → RDS PostgreSQL
```

## API Configuration Values

| Environment | API Base URL | How It's Set |
|------------|--------------|--------------|
| Local Dev | `http://localhost:8080` | Default in `api_config.dart` |
| Custom Local | User-specified | `--dart-define=API_BASE_URL=<url>` |
| Production | API Gateway URL | Extracted from Terraform by deployment script |

## How Values Are Passed

### Compile-Time (Recommended)
Values passed via `--dart-define` are baked into the JavaScript at build time:

```bash
flutter build web --dart-define=API_BASE_URL=https://example.com
```

**Advantages:**
- Type-safe (const values)
- Better performance (no runtime lookups)
- Simple architecture
- Works with CDN/static hosting

### NOT Using Runtime Configuration
We explicitly chose NOT to use runtime configuration (loading from JSON, window.location, etc.) because:
- Adds complexity
- Requires additional files/parsing
- Harder to debug
- API URLs are not secrets (visible in DevTools anyway)

## Security Notes

- **API URLs are public** - They're embedded in the compiled JavaScript, which is normal and expected
- **No secrets in frontend** - Never put API keys, passwords, or tokens in the frontend code
- **Authentication via JWT** - The backend validates requests using JWT tokens stored securely via `flutter_secure_storage`
- **HTTPS enforced in production** - CloudFront and API Gateway use HTTPS

## Troubleshooting

### Frontend connects to wrong backend
**Check current configuration:**
```bash
# View the ApiConfig file
cat frontend/lib/config/api_config.dart

# Test configuration
./tools/sh/test-api-config.sh
```

### Local development not working
**Verify backend is running:**
```bash
# Check if backend is listening on port 8080
lsof -i :8080

# Or test the health endpoint
curl http://localhost:8080/health
```

### Production frontend connects to localhost
**This means the deployment script didn't pass the API URL.**

Check:
1. Terraform state exists: `cd terraform/infra && terraform output api_gateway_url`
2. Deployment script was used: `./tools/sh/deploy-frontend.sh`
3. Build output shows the API URL: Check deployment script output

### CORS errors in browser
**The backend needs to allow the frontend origin.**

Check:
- Development: Backend should allow `http://localhost:*`
- Production: Backend should allow CloudFront URL

## Adding New API Endpoints

When adding new API endpoints:

1. ✅ **DO** use `HttpClientService` for all requests
2. ✅ **DO** reference endpoints via `ApiConfig` constants
3. ❌ **DON'T** hardcode URLs in service classes
4. ❌ **DON'T** create separate HTTP clients

Example:
```dart
// ✅ CORRECT
class MyService {
  final _httpClient = HttpClientService();

  Future<Data> getData() async {
    final response = await _httpClient.get(ApiConfig.myEndpoint);
    // ...
  }
}

// ❌ WRONG
class MyService {
  Future<Data> getData() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/data'));
    // ...
  }
}
```

## Related Documentation

- `/tools/sh/README.md` - Overview of all shell scripts
- `/terraform/infra/outputs.tf` - Terraform outputs including API Gateway URL
- `/backend/CLAUDE.md` - Backend development guidelines
- `/frontend/CLAUDE.md` - Frontend development guidelines

## Summary

✅ **What's already working:**
- ApiConfig with environment variable support
- HttpClientService using ApiConfig
- All services using HttpClientService
- Local development defaults to localhost

✅ **What was added:**
- Updated deployment script to extract and pass API Gateway URL
- Helper script for local development
- Configuration testing script
- This documentation

✅ **No code changes needed** in the core application - just deployment infrastructure!
