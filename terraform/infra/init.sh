#!/bin/bash
set -e

# Initialize Terraform with custom temp directory to avoid macOS permission issues
# This script ensures Terraform can download and install provider plugins

echo "=================================="
echo "Initializing Terraform"
echo "=================================="

# Create and use custom temp directory to avoid macOS /var/folders permission issues
export TMPDIR=~/tmp
export TMP=~/tmp
mkdir -p "$TMPDIR"

echo "Using temp directory: $TMPDIR"
echo ""

# Run terraform init
terraform init

echo ""
echo "=================================="
echo "Terraform Initialized Successfully"
echo "=================================="
echo ""
echo "Next steps:"
echo "  terraform plan    # Review changes"
echo "  terraform apply   # Deploy infrastructure"
echo ""