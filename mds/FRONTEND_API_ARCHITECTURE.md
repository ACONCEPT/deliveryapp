# Frontend API Architecture Diagram

## Overview

This document provides visual diagrams showing how the Flutter frontend connects to different backend endpoints in development vs production.

## Current Implementation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Frontend Code                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  ApiConfig                                              │    │
│  │  ┌────────────────────────────────────────────────┐    │    │
│  │  │ baseUrl = String.fromEnvironment(              │    │    │
│  │  │   'API_BASE_URL',                              │    │    │
│  │  │   defaultValue: 'http://localhost:8080'        │    │    │
│  │  │ )                                               │    │    │
│  │  └────────────────────────────────────────────────┘    │    │
│  │                                                          │    │
│  │  fullBaseUrl = '$baseUrl/api'                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  HttpClientService (Singleton)                          │    │
│  │  ┌────────────────────────────────────────────────┐    │    │
│  │  │ baseUrl = ApiConfig.baseUrl                    │    │    │
│  │  │                                                 │    │    │
│  │  │ get(path) => http.get('$baseUrl$path')        │    │    │
│  │  │ post(path, body) => http.post(...)            │    │    │
│  │  │ put(path, body) => http.put(...)              │    │    │
│  │  │ delete(path) => http.delete(...)              │    │    │
│  │  └────────────────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Service Layer (All API Services)                       │    │
│  │  ┌─────────────────────────────────────────────────┐   │    │
│  │  │ - ApiService (auth)                             │   │    │
│  │  │ - AddressService (addresses)                    │   │    │
│  │  │ - MenuService (menu)                            │   │    │
│  │  │ - OrderService (orders)                         │   │    │
│  │  │ - RestaurantService (restaurants)               │   │    │
│  │  │ - ApprovalService (admin approvals)             │   │    │
│  │  │ - SystemSettingsService (settings)              │   │    │
│  │  │ - DistanceService (distance calc)               │   │    │
│  │  └─────────────────────────────────────────────────┘   │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Development Environment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  Developer's Machine                             │
│                                                                  │
│  ┌──────────────────────────────┐                              │
│  │  Terminal                     │                              │
│  │                               │                              │
│  │  $ flutter run -d chrome      │                              │
│  │                               │                              │
│  │  (No --dart-define needed)    │                              │
│  │  Uses default localhost:8080  │                              │
│  └──────────────────────────────┘                              │
│                   │                                              │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Flutter Web App (Chrome)                                 │  │
│  │                                                            │  │
│  │  ApiConfig.baseUrl = 'http://localhost:8080'             │  │
│  │  ApiConfig.environment = 'dev'                            │  │
│  │                                                            │  │
│  │  All API calls go to:                                     │  │
│  │  → http://localhost:8080/api/*                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ HTTP Requests                                │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Go Backend Server                                        │  │
│  │                                                            │  │
│  │  Listening on localhost:8080                              │  │
│  │                                                            │  │
│  │  $ go run main.go                                         │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │  Gin Router                                          │ │  │
│  │  │  - /api/login                                        │ │  │
│  │  │  - /api/addresses                                    │ │  │
│  │  │  - /api/menu                                         │ │  │
│  │  │  - /api/orders                                       │ │  │
│  │  │  - /api/restaurants                                  │ │  │
│  │  │  - etc...                                            │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  Connected to: localhost PostgreSQL                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Cost: $0
Performance: Fast (local)
Database: Local PostgreSQL
```

## Production Environment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Build & Deploy Process                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  deploy-frontend.sh                                       │  │
│  │                                                            │  │
│  │  1. cd terraform/infra                                    │  │
│  │  2. API_URL=$(terraform output -raw api_gateway_url)     │  │
│  │                                                            │  │
│  │  3. cd frontend                                           │  │
│  │  4. flutter build web --release \                        │  │
│  │       --dart-define=API_BASE_URL="$API_URL" \            │  │
│  │       --dart-define=ENVIRONMENT=prod                      │  │
│  │                                                            │  │
│  │  5. aws s3 sync build/web/ s3://bucket/                  │  │
│  │  6. aws cloudfront create-invalidation ...                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Compiled Flutter App                                     │  │
│  │                                                            │  │
│  │  ApiConfig.baseUrl = 'https://abc123.execute-api...com'  │  │
│  │  ApiConfig.environment = 'prod'                           │  │
│  │                                                            │  │
│  │  (Compiled into JavaScript - immutable)                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             │ Uploaded to
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Infrastructure                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  S3 Bucket                                                │  │
│  │  delivery-app-frontend-prod-[account-id]                 │  │
│  │                                                            │  │
│  │  ├── index.html                                           │  │
│  │  ├── main.dart.js                                         │  │
│  │  ├── flutter.js                                           │  │
│  │  └── assets/                                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Served via                                   │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CloudFront Distribution                                  │  │
│  │                                                            │  │
│  │  Domain: https://d1234567890.cloudfront.net              │  │
│  │  (or custom domain if configured)                         │  │
│  │                                                            │  │
│  │  Features:                                                 │  │
│  │  - HTTPS enforced                                         │  │
│  │  - Global CDN caching                                     │  │
│  │  - Low latency                                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             │ User accesses
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       User's Browser                             │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  https://d1234567890.cloudfront.net                       │  │
│  │                                                            │  │
│  │  Flutter Web App Loaded                                   │  │
│  │  ApiConfig.baseUrl = 'https://abc123.execute-api...com'  │  │
│  │                                                            │  │
│  │  User logs in, browses menu, places order...             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ API Requests                                 │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway HTTP API                                     │  │
│  │                                                            │  │
│  │  URL: https://abc123.execute-api.us-east-1.amazonaws.com │  │
│  │                                                            │  │
│  │  Features:                                                 │  │
│  │  - HTTPS enforced                                         │  │
│  │  - CORS configured                                        │  │
│  │  - Rate limiting                                          │  │
│  │  - CloudWatch logging                                     │  │
│  │                                                            │  │
│  │  Routes:                                                   │  │
│  │  $default → Lambda (proxy all requests)                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Invokes                                      │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Lambda Function                                          │  │
│  │  delivery-app-backend-prod                                │  │
│  │                                                            │  │
│  │  Runtime: Go (compiled binary)                            │  │
│  │  Memory: 512MB                                            │  │
│  │  Timeout: 30s                                             │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │  Gin Router                                          │ │  │
│  │  │  - /api/login                                        │ │  │
│  │  │  - /api/addresses                                    │ │  │
│  │  │  - /api/menu                                         │ │  │
│  │  │  - /api/orders                                       │ │  │
│  │  │  - /api/restaurants                                  │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  Connected to: RDS PostgreSQL (via VPC)                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Database queries                             │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  RDS PostgreSQL                                           │  │
│  │  delivery-app-db-prod                                     │  │
│  │                                                            │  │
│  │  Instance: db.t3.micro                                    │  │
│  │  Storage: 20GB                                            │  │
│  │  Multi-AZ: Optional                                       │  │
│  │  Backups: Automated                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Cost: Pay-per-use (API Gateway, Lambda) + Fixed (RDS)
Performance: Scales automatically
Database: Managed PostgreSQL in AWS
```

## Configuration Comparison

```
┌──────────────────────────────────────────────────────────────────┐
│                    Development vs Production                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  DEVELOPMENT                      PRODUCTION                      │
│  ────────────────────────────     ─────────────────────────────  │
│                                                                   │
│  Build Command:                   Build Command:                 │
│  flutter run -d chrome            flutter build web --release \  │
│                                     --dart-define=API_BASE_URL=\  │
│                                     "https://xyz.amazonaws.com"   │
│                                                                   │
│  API URL:                         API URL:                       │
│  http://localhost:8080            https://[id].execute-api...    │
│                                                                   │
│  Environment:                     Environment:                   │
│  dev (default)                    prod (explicit)                │
│                                                                   │
│  Backend:                         Backend:                       │
│  Local Go server                  Lambda + API Gateway           │
│                                                                   │
│  Database:                        Database:                      │
│  Local PostgreSQL                 AWS RDS PostgreSQL             │
│                                                                   │
│  Protocol:                        Protocol:                      │
│  HTTP (localhost)                 HTTPS (SSL/TLS)                │
│                                                                   │
│  CORS:                            CORS:                          │
│  Not needed (same origin)         Configured in API Gateway      │
│                                                                   │
│  Authentication:                  Authentication:                │
│  JWT tokens                       JWT tokens                     │
│  Stored in secure storage         Stored in secure storage       │
│                                                                   │
│  Cost:                            Cost:                          │
│  $0                               Pay-per-use                    │
│                                                                   │
│  Speed:                           Speed:                         │
│  Very fast (local)                Fast (AWS network)             │
│                                                                   │
│  Debugging:                       Debugging:                     │
│  Direct console access            CloudWatch logs                │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Build-Time Configuration Injection

```
┌─────────────────────────────────────────────────────────────────┐
│                     Compile-Time Injection                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Build Command                                            │  │
│  │                                                            │  │
│  │  flutter build web --release \                           │  │
│  │    --dart-define=API_BASE_URL="https://api.example.com"  │  │
│  │    --dart-define=ENVIRONMENT="prod"                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Dart Compiler                                │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Compile-Time Constant Resolution                         │  │
│  │                                                            │  │
│  │  String.fromEnvironment('API_BASE_URL')                   │  │
│  │  → 'https://api.example.com'                              │  │
│  │                                                            │  │
│  │  String.fromEnvironment('ENVIRONMENT')                    │  │
│  │  → 'prod'                                                  │  │
│  │                                                            │  │
│  │  (Values are inlined into the compiled code)             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Dart2JS Compiler                             │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Compiled JavaScript                                      │  │
│  │                                                            │  │
│  │  var apiUrl = "https://api.example.com";                 │  │
│  │  var env = "prod";                                        │  │
│  │                                                            │  │
│  │  (Constants are baked into the JavaScript)               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   │                                              │
│                   │ Minification (--release)                     │
│                   ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Minified JavaScript                                      │  │
│  │                                                            │  │
│  │  var a="https://api.example.com";var b="prod";           │  │
│  │                                                            │  │
│  │  (Obfuscated but URL is still embedded)                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Benefits:
  ✓ Type-safe at compile time
  ✓ No runtime overhead
  ✓ No additional HTTP requests
  ✓ Environment-specific builds
  ✓ Cannot be changed after build

Security Note:
  - API URLs are public (visible in JavaScript)
  - This is normal and expected
  - Never include API keys or secrets in frontend
  - Authentication uses JWT tokens (not embedded)
```

## API Call Flow (Production)

```
User Browser                     CloudFront                API Gateway              Lambda                   RDS
    │                                │                         │                       │                       │
    │ 1. Load App                   │                         │                       │                       │
    ├──────────────────────────────►│                         │                       │                       │
    │                                │                         │                       │                       │
    │ 2. HTML + JS                  │                         │                       │                       │
    │◄──────────────────────────────┤                         │                       │                       │
    │                                │                         │                       │                       │
    │ 3. POST /api/login            │                         │                       │                       │
    ├────────────────────────────────────────────────────────►│                       │                       │
    │                                │                         │                       │                       │
    │                                │                         │ 4. Invoke Lambda      │                       │
    │                                │                         ├──────────────────────►│                       │
    │                                │                         │                       │                       │
    │                                │                         │                       │ 5. Query users table  │
    │                                │                         │                       ├──────────────────────►│
    │                                │                         │                       │                       │
    │                                │                         │                       │ 6. User data          │
    │                                │                         │                       │◄──────────────────────┤
    │                                │                         │                       │                       │
    │                                │                         │ 7. Generate JWT       │                       │
    │                                │                         │                       │                       │
    │                                │                         │ 8. Response           │                       │
    │                                │                         │◄──────────────────────┤                       │
    │                                │                         │                       │                       │
    │ 9. {token, user}              │                         │                       │                       │
    │◄────────────────────────────────────────────────────────┤                       │                       │
    │                                │                         │                       │                       │
    │ 10. Store token in            │                         │                       │                       │
    │     secure storage            │                         │                       │                       │
    │                                │                         │                       │                       │
    │ 11. GET /api/restaurants      │                         │                       │                       │
    │     Authorization: Bearer xxx │                         │                       │                       │
    ├────────────────────────────────────────────────────────►│                       │                       │
    │                                │                         │                       │                       │
    │                                │                         │ 12. Invoke Lambda     │                       │
    │                                │                         │     (with token)      │                       │
    │                                │                         ├──────────────────────►│                       │
    │                                │                         │                       │                       │
    │                                │                         │                       │ 13. Verify JWT        │
    │                                │                         │                       │                       │
    │                                │                         │                       │ 14. Query restaurants │
    │                                │                         │                       ├──────────────────────►│
    │                                │                         │                       │                       │
    │                                │                         │                       │ 15. Restaurant data   │
    │                                │                         │                       │◄──────────────────────┤
    │                                │                         │                       │                       │
    │                                │                         │ 16. Response          │                       │
    │                                │                         │◄──────────────────────┤                       │
    │                                │                         │                       │                       │
    │ 17. Restaurant list           │                         │                       │                       │
    │◄────────────────────────────────────────────────────────┤                       │                       │
    │                                │                         │                       │                       │
    │ 18. Render UI                 │                         │                       │                       │
    │                                │                         │                       │                       │

Notes:
- All communication uses HTTPS
- JWT token automatically added by HttpClientService
- API Gateway handles CORS preflight requests
- Lambda cold start: 1-2 seconds first request
- Lambda warm: 50-200ms subsequent requests
- CloudFront caches static assets (not API calls)
```

## Summary

### Key Points

1. **Configuration is Compile-Time**: API URLs are baked into the JavaScript during build
2. **Development Defaults to Localhost**: No configuration needed for local development
3. **Production Uses API Gateway**: Deployment script injects the URL from Terraform
4. **Single Codebase**: Same code works in both environments
5. **Secure by Design**: No secrets in frontend, tokens stored securely

### Files Involved

| File | Purpose | Changes Needed |
|------|---------|----------------|
| `ApiConfig.baseUrl` | Reads environment variable | None (already implemented) |
| `HttpClientService` | Uses ApiConfig | None (already implemented) |
| `deploy-frontend.sh` | Build & deploy script | Add `--dart-define` flag |
| All service files | Make API calls | None (already use HttpClientService) |

### Benefits

- ✅ Clean separation of concerns
- ✅ Environment-specific builds
- ✅ No runtime configuration needed
- ✅ Type-safe at compile time
- ✅ Works with CI/CD
- ✅ Minimal changes required
