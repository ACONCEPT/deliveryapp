#!/bin/bash
# Build script for migration Lambda function

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Building Migration Lambda Function                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$BACKEND_DIR/build"

echo "📁 Directories:"
echo "   Script: $SCRIPT_DIR"
echo "   Backend: $BACKEND_DIR"
echo "   Build: $BUILD_DIR"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# Check if go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed"
    exit 1
fi

echo "📋 Copying SQL files from source of truth..."
# Copy SQL files from backend/sql to embed them
cp "$BACKEND_DIR/sql/schema.sql" "$SCRIPT_DIR/schema.sql"
cp "$BACKEND_DIR/sql/drop_all.sql" "$SCRIPT_DIR/drop_all.sql"
echo "   ✓ schema.sql copied"
echo "   ✓ drop_all.sql copied"
echo ""

echo "🔨 Building migration Lambda function for Linux ARM64..."
cd "$SCRIPT_DIR"

# Build for Lambda (Linux ARM64)
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -tags lambda.norpc -o "$BUILD_DIR/migrate-bootstrap" .

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful: $BUILD_DIR/migrate-bootstrap"

# Cleanup temporary SQL files
echo ""
echo "🧹 Cleaning up temporary SQL files..."
rm -f "$SCRIPT_DIR/schema.sql" "$SCRIPT_DIR/drop_all.sql"
echo "   ✓ Temporary files removed"

# Create deployment package
echo ""
echo "📦 Creating deployment package..."
cd "$BUILD_DIR"

# Remove old zip if exists
rm -f migrate-lambda.zip

# Create zip with bootstrap as the handler
zip -q migrate-lambda.zip migrate-bootstrap

# Rename bootstrap to match Lambda requirement
mv migrate-bootstrap bootstrap
zip -q -u migrate-lambda.zip bootstrap
rm bootstrap

if [ $? -eq 0 ]; then
    echo "✅ Deployment package created: $BUILD_DIR/migrate-lambda.zip"

    # Show package size
    SIZE=$(ls -lh migrate-lambda.zip | awk '{print $5}')
    echo "   Size: $SIZE"
else
    echo "❌ Failed to create deployment package"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Migration Lambda Build Complete!                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployment package: $BUILD_DIR/migrate-lambda.zip"
echo ""
echo "To deploy with Terraform:"
echo "  cd terraform/infra"
echo "  terraform apply"
echo ""
echo "To test locally (requires AWS credentials):"
echo "  aws lambda invoke --function-name delivery-app-migrate-dev --payload '{\"action\":\"status\"}' /tmp/response.json"
echo "  cat /tmp/response.json"
echo ""
