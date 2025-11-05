#!/bin/bash

# Delivery App - Flutter Web Start Script
# This script starts the Flutter app in Chrome

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Flutter Web App - Delivery App                               ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT/frontend"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed"
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Create user-owned temp directory if TMPDIR has permission issues
if [ ! -w "$TMPDIR" ]; then
    echo "⚠️  System temp directory not writable, using alternate location..."
    export TMPDIR="$HOME/.flutter-tmp"
    mkdir -p "$TMPDIR"
fi

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  🚀 Starting Flutter Web App in Chrome...                           ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "The app will open in Chrome browser automatically."
echo ""
echo "📱 Test Accounts:"
echo "  • testcustomer / password123 (Customer)"
echo "  • testvendor   / password123 (Vendor)"
echo "  • testdriver   / password123 (Driver)"
echo "  • testadmin    / password123 (Admin)"
echo ""
echo "⚠️  Make sure the backend is running on http://localhost:8080"
echo ""
echo "🔥 Hot Reload Commands:"
echo "  r - Hot reload"
echo "  R - Hot restart"
echo "  q - Quit"
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Run Flutter in Chrome
flutter run -d chrome
