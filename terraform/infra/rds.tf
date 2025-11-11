# RDS PostgreSQL Database Instance
# Free Tier eligible: db.t3.micro or db.t4g.micro with up to 20GB storage

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-db-${var.environment}"

  # Engine Configuration
  engine         = "postgres"
  engine_version = "16.8" # Latest stable version

  # Instance Configuration (Free Tier)
  instance_class    = var.db_instance_class # db.t3.micro or db.t4g.micro
  allocated_storage = var.db_allocated_storage # Up to 20GB for Free Tier
  storage_type      = "gp3" # General Purpose SSD
  storage_encrypted = true

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password != "" ? var.db_password : random_password.db_password[0].result
  port     = 5432

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = var.db_publicly_accessible # Set to false for production

  # Backup Configuration
  backup_retention_period = var.db_backup_retention_days # 7 days for Free Tier
  backup_window           = "03:00-04:00" # UTC
  maintenance_window      = "mon:04:00-mon:05:00" # UTC

  # Performance and Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = false # Not available in Free Tier
  monitoring_interval             = 0 # Disable enhanced monitoring for Free Tier

  # High Availability (Disable for Free Tier)
  multi_az = false # Single AZ for Free Tier

  # Deletion Protection
  deletion_protection       = var.enable_deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Name = "${var.project_name}-database-${var.environment}"
  }

  lifecycle {
    ignore_changes = [
      password, # Prevent accidental password rotation
      final_snapshot_identifier
    ]
  }
}

# DB Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-postgres-params-${var.environment}"
  family = "postgres16"

  description = "Custom parameter group for ${var.project_name} PostgreSQL database"

  # Recommended settings for delivery app
  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot" # Static parameter requires reboot
  }

  parameter {
    name         = "shared_buffers"
    value        = "{DBInstanceClassMemory/32768}" # ~25% of memory
    apply_method = "pending-reboot" # Static parameter requires reboot
  }

  parameter {
    name         = "log_statement"
    value        = "all" # Log all statements (disable in production for performance)
    apply_method = "immediate" # Dynamic parameter
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000" # Log queries slower than 1 second
    apply_method = "immediate" # Dynamic parameter
  }

  tags = {
    Name = "${var.project_name}-postgres-params-${var.environment}"
  }
}

# Random password for database (if not provided)
resource "random_password" "db_password" {
  count            = var.db_password == "" ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"  # Exclude characters that RDS doesn't allow: / @ " ' ` \ space
}

# Store database credentials in Secrets Manager (optional but recommended)
resource "aws_secretsmanager_secret" "db_credentials" {
  count       = var.store_secrets_in_secrets_manager ? 1 : 0
  name        = "${var.project_name}/database-credentials-${var.environment}"
  description = "Database credentials for ${var.project_name}"

  recovery_window_in_days = 7

  # Use the default AWS managed key for Secrets Manager (no extra cost)
  kms_key_id = null

  tags = {
    Name = "${var.project_name}-db-credentials-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.store_secrets_in_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password != "" ? var.db_password : random_password.db_password[0].result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = var.db_name
    database_url = "postgres://${var.db_username}:${var.db_password != "" ? var.db_password : random_password.db_password[0].result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
  })

  depends_on = [
    aws_db_instance.postgres,
    aws_secretsmanager_secret.db_credentials
  ]

  lifecycle {
    ignore_changes = [secret_string]  # Prevent updates if password changes externally
  }
}