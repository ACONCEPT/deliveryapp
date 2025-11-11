#!/bin/bash
set -e

# Build script for scheduled jobs Lambda deployment package
# Creates a wrapper that invokes the jobs CLI commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_ZIP="$BUILD_DIR/lambda-jobs-deployment.zip"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building Scheduled Jobs Lambda Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create build directory
mkdir -p "$BUILD_DIR"

# Clean up any previous builds
rm -f "$OUTPUT_ZIP"
rm -rf "$BUILD_DIR/jobs-temp"
mkdir -p "$BUILD_DIR/jobs-temp"

echo ""
echo "Step 1: Compiling Go jobs CLI for Lambda (arm64 architecture)..."
cd "$BACKEND_DIR"

# Build the jobs CLI as a Lambda bootstrap
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build \
  -ldflags="-s -w" \
  -tags lambda.norpc \
  -o "$BUILD_DIR/jobs-temp/delivery_app" \
  main.go middleware.go

echo "✓ Go binary compiled successfully"

# Create Lambda handler wrapper script
echo ""
echo "Step 2: Creating Lambda handler wrapper..."

cat > "$BUILD_DIR/jobs-temp/bootstrap" << 'EOF'
#!/bin/bash
set -e

# Lambda handler wrapper for scheduled jobs
# Invokes the appropriate job based on JOB_NAME environment variable

JOB_NAME="${JOB_NAME:-unknown}"

echo "[Lambda] Starting scheduled job: $JOB_NAME"
echo "[Lambda] Environment: $ENVIRONMENT"
echo "[Lambda] Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

# Execute the job using the jobs CLI
case "$JOB_NAME" in
  cancel-unconfirmed-orders)
    /var/task/delivery_app jobs cancel-unconfirmed-orders
    ;;
  cleanup-orphaned-menus)
    /var/task/delivery_app jobs cleanup-orphaned-menus
    ;;
  archive-old-orders)
    /var/task/delivery_app jobs archive-old-orders
    ;;
  update-driver-availability)
    /var/task/delivery_app jobs update-driver-availability
    ;;
  *)
    echo "[ERROR] Unknown job name: $JOB_NAME"
    exit 1
    ;;
esac

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[Lambda] Job completed successfully"
else
  echo "[Lambda] Job failed with exit code: $EXIT_CODE"
  exit $EXIT_CODE
fi
EOF

chmod +x "$BUILD_DIR/jobs-temp/bootstrap"

echo "✓ Wrapper script created"

# Check binary size
BINARY_SIZE=$(du -h "$BUILD_DIR/jobs-temp/delivery_app" | cut -f1)
echo "  Binary size: $BINARY_SIZE"

echo ""
echo "Step 3: Creating deployment package..."

# Create zip file
cd "$BUILD_DIR/jobs-temp"
zip -q -r "$OUTPUT_ZIP" .

echo "✓ Deployment package created"

# Check zip size
ZIP_SIZE=$(du -h "$OUTPUT_ZIP" | cut -f1)
echo "  Package size: $ZIP_SIZE"

# Verify zip contents
echo ""
echo "Step 4: Verifying package contents..."
unzip -l "$OUTPUT_ZIP"

# Cleanup temp directory
cd "$BUILD_DIR"
rm -rf jobs-temp

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Jobs Lambda deployment package ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Package location: $OUTPUT_ZIP"
echo "Package size: $ZIP_SIZE"
echo ""
echo "Jobs included:"
echo "  • cancel-unconfirmed-orders (every 1 minute)"
echo "  • cleanup-orphaned-menus (daily at 2 AM UTC)"
echo "  • archive-old-orders (weekly on Sunday at 3 AM UTC)"
echo "  • update-driver-availability (every 5 minutes)"
echo ""
echo "Next steps:"
echo "  1. Run 'terraform plan' to review changes"
echo "  2. Run 'terraform apply' to deploy scheduled jobs"
echo ""

echo "Build completed successfully! 🎉"