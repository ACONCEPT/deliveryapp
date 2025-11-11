# Secrets Management Guide

This guide explains how to manage sensitive variables (JWT secrets, passwords, API tokens) for your Terraform deployment.

## ⚠️ Never Commit Secrets to Git!

The following files contain secrets and are already in `.gitignore`:
- `terraform.tfvars` - Your actual variable values
- `.env` - Environment variables
- Any files matching `.env.*`

## Option 1: terraform.tfvars File (✅ Recommended for Local Development)

This is the **simplest and most common approach** for local development.

### Setup

1. **File is already created** with a generated JWT secret:
   ```bash
   # The terraform.tfvars file exists with your secrets
   cat terraform.tfvars
   ```

2. **Edit if needed**:
   ```bash
   nano terraform.tfvars
   ```

3. **Deploy**:
   ```bash
   terraform apply
   # Terraform automatically reads terraform.tfvars
   ```

### Pros
✅ Simple - Terraform reads it automatically
✅ All secrets in one place
✅ Works offline
✅ Already in `.gitignore`

### Cons
❌ Secrets stored as plaintext on disk
❌ Not suitable for CI/CD pipelines
❌ Team members need their own copy

---

## Option 2: Environment Variables (Good for CI/CD)

Use environment variables to pass secrets without storing them in files.

### Setup

1. **Set variables directly**:
   ```bash
   export TF_VAR_jwt_secret="$(openssl rand -base64 48)"
   export TF_VAR_db_password="your-secure-password"
   export TF_VAR_mapbox_access_token="your-mapbox-token"
   ```

2. **Or use .env file** (recommended):
   ```bash
   # Create .env file
   cp .env.example .env

   # Edit with your secrets
   nano .env

   # Load variables
   source .env
   ```

3. **Deploy**:
   ```bash
   terraform apply
   # Uses environment variables (TF_VAR_*)
   ```

### Pros
✅ No plaintext files
✅ Great for CI/CD (GitHub Actions, CircleCI, etc.)
✅ Easy to rotate secrets
✅ Works with Docker containers

### Cons
❌ Must set variables in every terminal session
❌ Variables visible in process list
❌ Lost when terminal closes (unless in .env)

### CI/CD Example

**GitHub Actions:**
```yaml
- name: Deploy Infrastructure
  env:
    TF_VAR_jwt_secret: ${{ secrets.JWT_SECRET }}
    TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  run: terraform apply -auto-approve
```

**CircleCI:**
```yaml
- run:
    name: Deploy
    command: terraform apply -auto-approve
    environment:
      TF_VAR_jwt_secret: ${JWT_SECRET}
      TF_VAR_db_password: ${DB_PASSWORD}
```

---

## Option 3: AWS Secrets Manager (🔒 Best for Production)

Store secrets securely in AWS and reference them in Terraform.

### Setup

1. **Run the setup script**:
   ```bash
   ./scripts/setup-secrets.sh
   ```

   This creates secrets in AWS Secrets Manager:
   - `delivery-app/dev/jwt-secret`
   - `delivery-app/dev/db-password` (optional)
   - `delivery-app/dev/mapbox-token` (optional)

2. **Option A: Use environment variables**:
   ```bash
   # Fetch secret from AWS and set as env var
   export TF_VAR_jwt_secret=$(aws secretsmanager get-secret-value \
     --secret-id delivery-app/dev/jwt-secret \
     --query SecretString \
     --output text)

   terraform apply
   ```

3. **Option B: Modify Terraform to fetch directly** (advanced):

   Add to `variables.tf`:
   ```hcl
   variable "use_secrets_manager" {
     description = "Fetch secrets from AWS Secrets Manager"
     type        = bool
     default     = false
   }
   ```

   Add to `main.tf`:
   ```hcl
   data "aws_secretsmanager_secret_version" "jwt_secret" {
     count     = var.use_secrets_manager ? 1 : 0
     secret_id = "delivery-app/dev/jwt-secret"
   }

   locals {
     jwt_secret = var.use_secrets_manager ? data.aws_secretsmanager_secret_version.jwt_secret[0].secret_string : var.jwt_secret
   }
   ```

### Pros
✅ Most secure - encrypted at rest
✅ Centralized secret management
✅ Audit logs (who accessed what, when)
✅ Secret rotation support
✅ IAM-based access control

### Cons
❌ More complex setup
❌ Requires AWS API calls
❌ Additional cost (~$0.40/secret/month)
❌ Doesn't work offline

---

## Option 4: Command-Line Variables (Quick Tests)

Pass secrets directly on the command line:

```bash
terraform apply \
  -var="jwt_secret=$(openssl rand -base64 48)" \
  -var="db_password=mysecurepassword"
```

### Pros
✅ Quick for testing
✅ No files to manage

### Cons
❌ Secrets visible in shell history
❌ Tedious for multiple variables
❌ Not suitable for production

---

## Comparison Table

| Method | Security | Convenience | CI/CD | Team Use | Production Ready |
|--------|----------|-------------|-------|----------|------------------|
| **terraform.tfvars** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | ⭐ | ⭐⭐ |
| **Environment Vars** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | ⭐⭐⭐ | ⭐⭐⭐ |
| **AWS Secrets Manager** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ✅ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Command-Line** | ⭐ | ⭐ | ❌ | ⭐ | ❌ |

---

## Recommended Approach by Environment

### Development (Local)
Use **terraform.tfvars** - already set up for you!

```bash
# Already created with secrets
terraform apply
```

### Staging/Testing
Use **Environment Variables** with `.env` file:

```bash
source .env
terraform apply
```

### Production
Use **AWS Secrets Manager**:

```bash
./scripts/setup-secrets.sh
export TF_VAR_jwt_secret=$(aws secretsmanager get-secret-value ...)
terraform apply
```

---

## Rotating Secrets

### Generate New JWT Secret

```bash
# Generate new secret
NEW_SECRET=$(openssl rand -base64 48)

# Update terraform.tfvars
sed -i '' "s/jwt_secret = .*/jwt_secret = \"$NEW_SECRET\"/" terraform.tfvars

# Or update in AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id delivery-app/dev/jwt-secret \
  --secret-string "$NEW_SECRET"

# Apply changes
terraform apply
```

### Update Database Password

⚠️ **Warning**: Changing DB password requires careful coordination!

```bash
# 1. Update Terraform variable
# 2. Apply (this updates Lambda env vars)
terraform apply

# 3. Update RDS password manually (or use Terraform)
aws rds modify-db-instance \
  --db-instance-identifier delivery-app-db-dev \
  --master-user-password "new-password" \
  --apply-immediately
```

---

## Security Best Practices

### ✅ Do

- **Use `.gitignore`** to exclude secret files (already configured)
- **Generate strong secrets**: `openssl rand -base64 48`
- **Use different secrets** for dev/staging/prod
- **Rotate secrets regularly** (every 90 days)
- **Use AWS Secrets Manager** for production
- **Enable encryption** on state backend (already enabled)
- **Review access logs** regularly

### ❌ Don't

- **Never commit** `terraform.tfvars` to git
- **Never commit** `.env` files
- **Never hardcode** secrets in `.tf` files
- **Never share** secrets via email/Slack
- **Never use** same secrets across environments
- **Never log** secrets to console
- **Avoid** storing secrets in shell history

---

## Troubleshooting

### "Error: No value for required variable"

Terraform can't find your secret. Solutions:

```bash
# Option 1: Check terraform.tfvars exists
ls -la terraform.tfvars

# Option 2: Set environment variable
export TF_VAR_jwt_secret="your-secret"

# Option 3: Pass on command line
terraform apply -var="jwt_secret=your-secret"
```

### "Secret value is sensitive"

This is normal! Terraform hides sensitive values in output. To view:

```bash
# View (careful - exposes secret!)
terraform output -raw jwt_secret
```

### "aws_secretsmanager_secret already exists"

Secret already created. Update it instead:

```bash
aws secretsmanager update-secret \
  --secret-id delivery-app/dev/jwt-secret \
  --secret-string "new-value"
```

---

## Current Setup

Your deployment is currently using **terraform.tfvars** with:

✅ JWT secret (auto-generated)
✅ Database password (auto-generate on apply)
⚠️ Mapbox token (empty - add if needed)

**File location**: `terraform/infra/terraform.tfvars`
**Status**: Ready to deploy!

Just run `terraform apply` - secrets are already configured! 🚀