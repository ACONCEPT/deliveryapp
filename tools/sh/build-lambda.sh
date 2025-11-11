#!/bin/bash
set -e

# Build Lambda deployment packages for AWS deployment
# This script builds:
# 1. Main backend API Lambda function
# 2. Scheduled jobs Lambda functions (as a combined package)

# Set TMPDIR to user's temp directory to avoid permission issues
# Create a user-specific temp directory if needed
USER_TEMP_DIR="$HOME/.tmp"
mkdir -p "$USER_TEMP_DIR"
export TMPDIR="$USER_TEMP_DIR"
export GOCACHE="$USER_TEMP_DIR/go-cache"
export GOMODCACHE="$USER_TEMP_DIR/go-mod"

echo "=================================="
echo "Building Lambda Deployment Packages"
echo "=================================="

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create build directory
echo ""
echo "[1/4] Creating build directory..."
mkdir -p build/lambda-temp
mkdir -p build/lambda-jobs-temp

# Add AWS Lambda dependencies to go.mod if not present
echo ""
echo "[2/4] Installing AWS Lambda dependencies..."
cd ../../backend
if ! grep -q "github.com/aws/aws-lambda-go" go.mod 2>/dev/null; then
    echo "Adding aws-lambda-go dependency..."
    go get github.com/aws/aws-lambda-go/lambda
    go get github.com/aws/aws-lambda-go/events
fi
if ! grep -q "github.com/awslabs/aws-lambda-go-api-proxy" go.mod 2>/dev/null; then
    echo "Adding aws-lambda-go-api-proxy dependency..."
    go get github.com/awslabs/aws-lambda-go-api-proxy/httpadapter
fi
go mod tidy
cd ..

# Build main backend Lambda function
echo ""
echo "[3/4] Building main backend API Lambda..."
cd backend
# Build the main HTTP server (main.go) for use with Lambda Web Adapter
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../build/lambda-temp/bootstrap main.go
cd ..

# Package main backend Lambda
cd build/lambda-temp
zip -r ../lambda-deployment.zip bootstrap
cd ../..
echo "✓ Created build/lambda-deployment.zip"

# Build scheduled jobs Lambda functions (combined package)
echo ""
echo "[4/4] Building scheduled jobs Lambdas..."

# Build each job handler
cd backend
echo "  - Building cancel-unconfirmed-orders..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../build/lambda-jobs-temp/cancel-unconfirmed-orders cmd/lambda-jobs/cancel-unconfirmed-orders/main.go

echo "  - Building cleanup-orphaned-menus..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../build/lambda-jobs-temp/cleanup-orphaned-menus cmd/lambda-jobs/cleanup-orphaned-menus/main.go

echo "  - Building archive-old-orders..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../build/lambda-jobs-temp/archive-old-orders cmd/lambda-jobs/archive-old-orders/main.go

echo "  - Building update-driver-availability..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o ../build/lambda-jobs-temp/update-driver-availability cmd/lambda-jobs/update-driver-availability/main.go
cd ..

# Package all jobs into a single zip (each job will be deployed separately but use the same code)
cd build/lambda-jobs-temp
# Each job needs to be named 'bootstrap' for Lambda, so we'll create separate zips
cd ..
mkdir -p lambda-jobs-final

# Create individual job packages
for job in cancel-unconfirmed-orders cleanup-orphaned-menus archive-old-orders update-driver-availability; do
    mkdir -p lambda-jobs-final/$job
    cp lambda-jobs-temp/$job lambda-jobs-final/$job/bootstrap
    cd lambda-jobs-final/$job
    zip ../../lambda-jobs-deployment-$job.zip bootstrap
    cd ../..
done

# For the combined package variable, create one with all binaries
cd lambda-jobs-temp
zip -r ../lambda-jobs-deployment.zip *
cd ..

echo "✓ Created build/lambda-jobs-deployment.zip (combined)"
echo "✓ Created individual job packages:"
echo "  - build/lambda-jobs-deployment-cancel-unconfirmed-orders.zip"
echo "  - build/lambda-jobs-deployment-cleanup-orphaned-menus.zip"
echo "  - build/lambda-jobs-deployment-archive-old-orders.zip"
echo "  - build/lambda-jobs-deployment-update-driver-availability.zip"
cd ..

# Clean up temp directories
echo ""
echo "Cleaning up temporary build files..."
rm -rf build/lambda-temp
rm -rf build/lambda-jobs-temp
rm -rf build/lambda-jobs-final

# Display package sizes
echo ""
echo "=================================="
echo "Build Complete!"
echo "=================================="
echo ""
echo "Package sizes:"
ls -lh build/lambda-deployment.zip
ls -lh build/lambda-jobs-deployment*.zip
echo ""
echo "Deployment packages are ready in ./build/"
echo ""
echo "Next steps:"
echo "1. cd terraform/infra"
echo "2. terraform plan"
echo "3. terraform apply"
echo ""
