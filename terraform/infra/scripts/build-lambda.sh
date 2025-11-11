#!/bin/bash
set -e

# Build script for Lambda deployment package
# This script compiles the Go backend and creates a zip file for Lambda deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_ZIP="$BUILD_DIR/lambda-deployment.zip"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building Lambda Deployment Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create build directory
mkdir -p "$BUILD_DIR"

# Clean up any previous builds
rm -f "$OUTPUT_ZIP"
rm -rf "$BUILD_DIR/lambda-temp"
mkdir -p "$BUILD_DIR/lambda-temp"

echo ""
echo "Step 1: Compiling Go backend for Lambda (arm64 architecture)..."
cd "$BACKEND_DIR"

# Build for Lambda custom runtime (provided.al2023)
# Architecture: arm64 (cheaper and faster than x86_64)
# Output: bootstrap (required name for Go custom runtime)
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build \
  -ldflags="-s -w" \
  -tags lambda.norpc \
  -o "$BUILD_DIR/lambda-temp/bootstrap" \
  main.go middleware.go

echo "✓ Go binary compiled successfully"

# Check binary size
BINARY_SIZE=$(du -h "$BUILD_DIR/lambda-temp/bootstrap" | cut -f1)
echo "  Binary size: $BINARY_SIZE"

echo ""
echo "Step 2: Creating deployment package..."

# Copy SQL schema files (for migrations)
echo "  • Copying SQL schema files..."
mkdir -p "$BUILD_DIR/lambda-temp/sql"
cp -r "$BACKEND_DIR/sql/"*.sql "$BUILD_DIR/lambda-temp/sql/" 2>/dev/null || true

# Create zip file
cd "$BUILD_DIR/lambda-temp"
zip -q -r "$OUTPUT_ZIP" .

echo "✓ Deployment package created"

# Check zip size
ZIP_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1)
echo "  Package size: $ZIP_SIZE"

# Verify zip contents
echo ""
echo "Step 3: Verifying package contents..."
unzip -l "$OUTPUT_ZIP" | grep -E "(bootstrap|sql/)"

# Cleanup temp directory
cd "$BUILD_DIR"
rm -rf lambda-temp

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Lambda deployment package ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Package location: $OUTPUT_ZIP"
echo "Package size: $ZIP_SIZE"
echo ""
echo "Next steps:"
echo "  1. Run 'terraform plan' to review changes"
echo "  2. Run 'terraform apply' to deploy to AWS"
echo ""

# Check Lambda size limits
MAX_ZIP_SIZE=$((50 * 1024 * 1024))  # 50 MB
ACTUAL_SIZE=$(stat -f%z "$OUTPUT_ZIP" 2>/dev/null || stat -c%s "$OUTPUT_ZIP" 2>/dev/null)

if [ "$ACTUAL_SIZE" -gt "$MAX_ZIP_SIZE" ]; then
  echo "⚠️  WARNING: Package size exceeds 50MB limit for direct upload"
  echo "   You may need to use S3 for deployment"
  echo ""
fi

echo "Build completed successfully! 🎉"