#!/bin/bash
set -e

# Script to store secrets in AWS Secrets Manager
# Run this once to store your secrets securely in AWS

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Terraform Secrets Setup (AWS Secrets Manager)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_NAME=${1:-delivery-app}
ENVIRONMENT=${2:-dev}

# Generate JWT secret if not provided
JWT_SECRET=$(openssl rand -base64 48)

echo "Generated JWT secret: ${JWT_SECRET:0:20}..."
echo ""

# Create secret in AWS Secrets Manager
echo "Creating secrets in AWS Secrets Manager..."

# JWT Secret
aws secretsmanager create-secret \
  --name "${PROJECT_NAME}/${ENVIRONMENT}/jwt-secret" \
  --description "JWT secret for ${PROJECT_NAME} ${ENVIRONMENT}" \
  --secret-string "$JWT_SECRET" \
  --region us-east-1 \
  2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/jwt-secret" \
  --secret-string "$JWT_SECRET" \
  --region us-east-1

echo "✓ JWT secret stored"

# Database password (optional - let Terraform generate it)
read -p "Set database password? (y/n, or press Enter to auto-generate) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  read -sp "Enter database password: " DB_PASSWORD
  echo

  aws secretsmanager create-secret \
    --name "${PROJECT_NAME}/${ENVIRONMENT}/db-password" \
    --description "Database password for ${PROJECT_NAME} ${ENVIRONMENT}" \
    --secret-string "$DB_PASSWORD" \
    --region us-east-1 \
    2>/dev/null || \
  aws secretsmanager update-secret \
    --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/db-password" \
    --secret-string "$DB_PASSWORD" \
    --region us-east-1

  echo "✓ Database password stored"
fi

# Mapbox token (optional)
read -p "Do you have a Mapbox access token? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  read -p "Enter Mapbox access token: " MAPBOX_TOKEN

  aws secretsmanager create-secret \
    --name "${PROJECT_NAME}/${ENVIRONMENT}/mapbox-token" \
    --description "Mapbox access token for ${PROJECT_NAME} ${ENVIRONMENT}" \
    --secret-string "$MAPBOX_TOKEN" \
    --region us-east-1 \
    2>/dev/null || \
  aws secretsmanager update-secret \
    --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/mapbox-token" \
    --secret-string "$MAPBOX_TOKEN" \
    --region us-east-1

  echo "✓ Mapbox token stored"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secrets stored successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To use these secrets with Terraform:"
echo ""
echo "1. Add data sources to your Terraform config:"
echo ""
cat << 'EOF'
data "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = "delivery-app/dev/jwt-secret"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "delivery-app/dev/db-password"
}

# In your resources:
jwt_secret  = data.aws_secretsmanager_secret_version.jwt_secret.secret_string
db_password = data.aws_secretsmanager_secret_version.db_password.secret_string
EOF
echo ""
echo "2. Or use environment variables:"
echo ""
echo "export TF_VAR_jwt_secret=\$(aws secretsmanager get-secret-value --secret-id ${PROJECT_NAME}/${ENVIRONMENT}/jwt-secret --query SecretString --output text)"
echo ""
echo "Done! 🎉"