# Frontend Environment Configuration - Document Index

This directory contains comprehensive documentation for configuring the Flutter frontend to work with different backend endpoints (localhost for development, AWS API Gateway for production).

## Quick Start

**If you just want the summary, read this first:**
- [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md) - 5-minute overview

**If you want complete implementation details:**
- [FRONTEND_ENVIRONMENT_CONFIG_PLAN.md](./FRONTEND_ENVIRONMENT_CONFIG_PLAN.md) - Full implementation plan

**If you want to understand the architecture:**
- [FRONTEND_API_ARCHITECTURE.md](./FRONTEND_API_ARCHITECTURE.md) - Visual diagrams and flow charts

## Document Overview

### 1. FRONTEND_API_CONFIG_SUMMARY.md
**Purpose:** Quick reference guide
**Audience:** Developers, DevOps engineers
**Read Time:** 5 minutes
**Contains:**
- Current state analysis
- What needs to change (one file)
- Quick commands for dev and prod
- Common issues and solutions
- Why we chose this approach

**When to use:** You need a quick overview or refresher

### 2. FRONTEND_ENVIRONMENT_CONFIG_PLAN.md
**Purpose:** Comprehensive implementation guide
**Audience:** Lead developers, architects
**Read Time:** 30 minutes
**Contains:**
- Detailed current state analysis
- Complete implementation plan with code samples
- Step-by-step implementation checklist
- Testing procedures
- Security considerations
- Alternative approaches (and why rejected)
- Cost analysis
- Monitoring and debugging guide
- Troubleshooting section

**When to use:** You're implementing the changes or need deep understanding

### 3. FRONTEND_API_ARCHITECTURE.md
**Purpose:** Visual architecture documentation
**Audience:** Developers, technical leads, stakeholders
**Read Time:** 15 minutes
**Contains:**
- Architecture diagrams (ASCII art)
- Development vs production flow charts
- Configuration injection visualization
- API call sequence diagrams
- Comparison tables

**When to use:** You need to understand how the system works visually

### 4. Shell Scripts (Ready to Use)

#### deploy-frontend-updated.sh
**Purpose:** Updated deployment script for production
**Usage:**
```bash
# Copy to tools/sh/ directory
cp mds/deploy-frontend-updated.sh tools/sh/deploy-frontend.sh
chmod +x tools/sh/deploy-frontend.sh

# Deploy to production
./tools/sh/deploy-frontend.sh
```

**Features:**
- Extracts API Gateway URL from Terraform
- Builds Flutter with production config
- Deploys to S3 and invalidates CloudFront
- Comprehensive error handling

#### run-local-frontend.sh
**Purpose:** Helper script for local development
**Usage:**
```bash
# Copy to tools/sh/ directory
cp mds/run-local-frontend.sh tools/sh/
chmod +x tools/sh/run-local-frontend.sh

# Run locally
./tools/sh/run-local-frontend.sh
```

**Features:**
- Checks if backend is running
- Runs Flutter with explicit localhost config
- User-friendly prompts

#### test-api-config.sh
**Purpose:** Test configuration setup
**Usage:**
```bash
# Copy to tools/sh/ directory
cp mds/test-api-config.sh tools/sh/
chmod +x tools/sh/test-api-config.sh

# Test configuration
./tools/sh/test-api-config.sh
```

**Features:**
- Tests development build
- Tests production build
- Verifies URLs in compiled output

## Implementation Workflow

### For Developers (Local Development)
1. Read: [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md)
2. No changes needed - just run:
   ```bash
   cd frontend
   flutter run -d chrome
   ```

### For DevOps (Production Deployment)
1. Read: [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md)
2. Review: [deploy-frontend-updated.sh](./deploy-frontend-updated.sh)
3. Copy script to `tools/sh/deploy-frontend.sh`
4. Run: `./tools/sh/deploy-frontend.sh`

### For Architects (System Design)
1. Read: [FRONTEND_ENVIRONMENT_CONFIG_PLAN.md](./FRONTEND_ENVIRONMENT_CONFIG_PLAN.md)
2. Review: [FRONTEND_API_ARCHITECTURE.md](./FRONTEND_API_ARCHITECTURE.md)
3. Understand tradeoffs and alternatives
4. Make informed decisions

### For Technical Leads (Code Review)
1. Read: [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md)
2. Review: [FRONTEND_ENVIRONMENT_CONFIG_PLAN.md](./FRONTEND_ENVIRONMENT_CONFIG_PLAN.md) (Implementation Checklist section)
3. Check: [deploy-frontend-updated.sh](./deploy-frontend-updated.sh)
4. Verify implementation against plan

## Quick Reference

### Current State
- ✅ Frontend already supports `--dart-define`
- ✅ ApiConfig reads from environment variables
- ✅ HttpClientService uses ApiConfig
- ✅ All services use HttpClientService
- ⚠️ Deployment script needs updating

### Required Changes
- 🔧 Update `tools/sh/deploy-frontend.sh` (one file)
- 📝 Optional: Add helper scripts
- 📚 Optional: Update documentation

### Time Estimate
- Script updates: 30 minutes
- Testing: 1 hour
- Documentation: 30 minutes
- **Total: 2 hours**

### Risk Level
- **Low Risk** - Changes are additive, no breaking changes

## File Locations

### Documentation Files (This Directory)
```
mds/
├── FRONTEND_CONFIG_INDEX.md              (This file)
├── FRONTEND_API_CONFIG_SUMMARY.md        (Quick summary)
├── FRONTEND_ENVIRONMENT_CONFIG_PLAN.md   (Detailed plan)
├── FRONTEND_API_ARCHITECTURE.md          (Visual diagrams)
├── deploy-frontend-updated.sh            (Updated deploy script)
├── run-local-frontend.sh                 (Local dev helper)
└── test-api-config.sh                    (Config test script)
```

### Implementation Files (To Be Modified)
```
tools/sh/
└── deploy-frontend.sh                    (Needs updating)

frontend/lib/config/
└── api_config.dart                       (Already correct)

frontend/lib/services/
└── http_client_service.dart              (Already correct)
```

## Common Questions

### Q: Do I need to change any Dart code?
**A:** No. The existing code already supports environment variables via `String.fromEnvironment()`.

### Q: What about local development?
**A:** No changes needed. It defaults to `localhost:8080`.

### Q: How do I deploy to production?
**A:** Update the deployment script and run it. The script handles everything.

### Q: Can I use different API URLs for staging?
**A:** Yes. The updated script supports `--env staging` parameter.

### Q: Is this secure?
**A:** Yes. API URLs are public (visible in browser). Secrets use JWT tokens stored securely.

### Q: What if I want to use environment files (.env)?
**A:** Not recommended. See "Alternative Approaches Considered" in the detailed plan for why.

### Q: How do I debug API calls?
**A:** Check browser console for "API Configuration" log. Also check CloudWatch logs for Lambda.

### Q: What about CORS issues?
**A:** Ensure CloudFront URL is in API Gateway CORS allowed origins (configured in Terraform).

## Decision Tree

```
START: What do you need?

├─ Quick overview of what to do?
│  └─► Read: FRONTEND_API_CONFIG_SUMMARY.md
│
├─ Visual understanding of architecture?
│  └─► Read: FRONTEND_API_ARCHITECTURE.md
│
├─ Implementing the changes?
│  └─► Read: FRONTEND_ENVIRONMENT_CONFIG_PLAN.md
│     └─► Use: deploy-frontend-updated.sh
│
├─ Setting up local development?
│  └─► Read: FRONTEND_API_CONFIG_SUMMARY.md (Development section)
│     └─► Use: run-local-frontend.sh
│
├─ Testing the configuration?
│  └─► Use: test-api-config.sh
│
├─ Troubleshooting issues?
│  └─► Read: FRONTEND_ENVIRONMENT_CONFIG_PLAN.md (Monitoring & Debugging section)
│
└─ Understanding why we chose this approach?
   └─► Read: FRONTEND_ENVIRONMENT_CONFIG_PLAN.md (Alternative Approaches section)
```

## Next Steps

### Immediate Actions
1. [ ] Review [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md)
2. [ ] Copy [deploy-frontend-updated.sh](./deploy-frontend-updated.sh) to `tools/sh/`
3. [ ] Test locally with existing setup (should work as-is)
4. [ ] Deploy to production using updated script
5. [ ] Verify API calls work in production
6. [ ] Update team documentation

### Optional Actions
1. [ ] Copy helper scripts to `tools/sh/`
2. [ ] Run [test-api-config.sh](./test-api-config.sh) to verify setup
3. [ ] Create frontend README.md with usage instructions
4. [ ] Add environment configuration to team wiki
5. [ ] Train team on deployment process

## Success Criteria

### Checklist
- [ ] Local development works without configuration
- [ ] Production deployment uses API Gateway URL
- [ ] API calls succeed in both environments
- [ ] No CORS errors
- [ ] Authentication works
- [ ] Configuration logged on app startup
- [ ] Team understands the setup
- [ ] Documentation is complete

### Verification Steps
1. **Local:**
   ```bash
   cd frontend
   flutter run -d chrome
   # Open browser console
   # Verify "API Configuration" shows localhost:8080
   # Test login
   ```

2. **Production:**
   ```bash
   ./tools/sh/deploy-frontend.sh
   # Open CloudFront URL
   # Open browser console
   # Verify "API Configuration" shows API Gateway URL
   # Test login
   ```

## Support

### Resources
- Flutter Environment Variables: https://dart.dev/guides/environment-declarations
- API Gateway CORS: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-cors.html
- CloudFront Invalidation: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html

### Troubleshooting
See "Common Issues & Solutions" in [FRONTEND_API_CONFIG_SUMMARY.md](./FRONTEND_API_CONFIG_SUMMARY.md)

See "Monitoring & Debugging" in [FRONTEND_ENVIRONMENT_CONFIG_PLAN.md](./FRONTEND_ENVIRONMENT_CONFIG_PLAN.md)

## Document Maintenance

### Last Updated
November 10, 2025

### Version
1.0.0

### Authors
Claude Code (Frontend Engineer Agent)

### Review Schedule
- Review after first production deployment
- Update if architecture changes
- Update if new environments added (e.g., staging)
- Update if deployment process changes
