#!/bin/bash

# Invoke Migration Lambda
# This script invokes the AWS Lambda function that runs database migrations

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Invoke Migration Lambda                                     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
FUNCTION_NAME="delivery-app-migrate-dev"
REGION="us-east-1"
ACTION="${1:-migrate}" # Default to migrate

# Available actions: migrate, status, drop, seed
case $ACTION in
  migrate|status|drop|seed)
    echo "Action: $ACTION"
    ;;
  *)
    echo "❌ Invalid action: $ACTION"
    echo ""
    echo "Usage: $0 [ACTION]"
    echo ""
    echo "Available actions:"
    echo "  migrate - Run full database migration (drop + schema)"
    echo "  status  - Check database status (table count)"
    echo "  drop    - Drop all database objects"
    echo "  seed    - Seed test data"
    echo ""
    exit 1
    ;;
esac

# Create payload
PAYLOAD="{\"action\":\"$ACTION\"}"

echo "Function: $FUNCTION_NAME"
echo "Region: $REGION"
echo "Payload: $PAYLOAD"
echo ""

# Invoke Lambda
echo "🚀 Invoking Lambda function..."

# Use --cli-binary-format raw-in-base64-out to avoid base64 encoding issues
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --cli-binary-format raw-in-base64-out \
  --payload "$PAYLOAD" \
  /tmp/migrate-response.json \
  --query '{StatusCode:StatusCode,FunctionError:FunctionError}' \
  --output json

echo ""
echo "📄 Response:"
cat /tmp/migrate-response.json | python3 -m json.tool 2>/dev/null || cat /tmp/migrate-response.json
echo ""

# Check for errors
if grep -q '"success":false' /tmp/migrate-response.json 2>/dev/null; then
    echo "❌ Migration failed - check response above"
    exit 1
elif grep -q 'errorType' /tmp/migrate-response.json 2>/dev/null; then
    echo "❌ Lambda execution failed - check CloudWatch logs:"
    echo "   aws logs tail /aws/lambda/$FUNCTION_NAME --region $REGION --since 5m --follow"
    exit 1
else
    echo "✅ Lambda executed successfully"
fi

echo ""
echo "To view logs:"
echo "  aws logs tail /aws/lambda/$FUNCTION_NAME --region $REGION --since 10m --follow"
echo ""
