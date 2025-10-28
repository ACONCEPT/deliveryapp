#!/bin/bash

# Delivery App - Stop All Services Script
# This script stops all running services

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Stop All Services - Delivery App                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🛑 Stopping Docker services..."
docker-compose down

echo ""
echo "🔍 Checking for running backend processes..."
if pgrep -f "delivery_app" > /dev/null; then
    echo "   Found running backend process"
    pkill -f "delivery_app" || true
    echo "   ✅ Backend stopped"
else
    echo "   No backend process running"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ All Services Stopped!                                            ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
