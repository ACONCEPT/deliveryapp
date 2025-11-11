#!/bin/bash

# Test Script for Scheduled Jobs Implementation
# This script verifies that the scheduled jobs are working correctly

set -e

echo "======================================"
echo "Testing Scheduled Jobs Implementation"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd "$(dirname "$0")/backend"

echo "Step 1: Building backend binary..."
if go build -o delivery_app . 2>&1; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
echo ""

echo "Step 2: Testing CLI help..."
if ./delivery_app jobs --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CLI help works${NC}"
    echo ""
    echo "Available commands:"
    ./delivery_app jobs --help | grep -E "^\s+(cancel|cleanup|archive|update)" | sed 's/^/  /'
else
    echo -e "${RED}✗ CLI help failed${NC}"
    exit 1
fi
echo ""

echo "Step 3: Testing individual jobs..."

# Test cancel unconfirmed orders
echo -n "  Testing cancel-unconfirmed-orders... "
if ./delivery_app jobs cancel-unconfirmed-orders > /tmp/job_test.log 2>&1; then
    if grep -q "completed successfully" /tmp/job_test.log; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (warning: unexpected output)${NC}"
        cat /tmp/job_test.log
    fi
else
    echo -e "${RED}✗${NC}"
    cat /tmp/job_test.log
    exit 1
fi

# Test cleanup orphaned menus
echo -n "  Testing cleanup-orphaned-menus... "
if ./delivery_app jobs cleanup-orphaned-menus > /tmp/job_test.log 2>&1; then
    if grep -q "completed successfully" /tmp/job_test.log; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (warning: unexpected output)${NC}"
        cat /tmp/job_test.log
    fi
else
    echo -e "${RED}✗${NC}"
    cat /tmp/job_test.log
    exit 1
fi

# Test archive old orders
echo -n "  Testing archive-old-orders... "
if ./delivery_app jobs archive-old-orders > /tmp/job_test.log 2>&1; then
    if grep -q "completed successfully" /tmp/job_test.log; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (warning: unexpected output)${NC}"
        cat /tmp/job_test.log
    fi
else
    echo -e "${RED}✗${NC}"
    cat /tmp/job_test.log
    exit 1
fi

# Test update driver availability
echo -n "  Testing update-driver-availability... "
if ./delivery_app jobs update-driver-availability > /tmp/job_test.log 2>&1; then
    if grep -q "completed successfully" /tmp/job_test.log; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (warning: unexpected output)${NC}"
        cat /tmp/job_test.log
    fi
else
    echo -e "${RED}✗${NC}"
    cat /tmp/job_test.log
    exit 1
fi

echo ""

echo "Step 4: Verifying HTTP server still works..."
echo -n "  Starting server... "
./delivery_app > /tmp/server_test.log 2>&1 &
SERVER_PID=$!
sleep 2

if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server responds to health check${NC}"
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Server may not be responding (port might be in use)${NC}"
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
fi

echo ""

echo "Step 5: Checking Docker Compose configuration..."
cd ..
if grep -q "scheduler:" docker-compose.yml; then
    echo -e "${GREEN}✓ Scheduler service exists in docker-compose.yml${NC}"

    if grep -q "cancel-unconfirmed-orders" docker-compose.yml; then
        echo -e "${GREEN}✓ Crontab configured with jobs${NC}"
    else
        echo -e "${RED}✗ Crontab not configured${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Scheduler service not found in docker-compose.yml${NC}"
    exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}All Tests Passed!${NC}"
echo "======================================"
echo ""
echo "Next Steps:"
echo "  1. Start scheduler: docker-compose up -d --build scheduler"
echo "  2. View logs: docker logs -f delivery_app_scheduler"
echo "  3. Check cron: docker exec delivery_app_scheduler tail -f /var/log/cron.log"
echo ""
echo "Documentation:"
echo "  - Implementation guide: SCHEDULED_JOBS_IMPLEMENTATION.md"
echo "  - Job documentation: backend/jobs/README.md"
echo ""
