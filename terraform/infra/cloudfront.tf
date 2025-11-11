# S3 Bucket for Flutter Web Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-frontend-${var.environment}"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block (block all, CloudFront will access via OAC)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing: redirect all errors to index.html
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac-${var.environment}"
  description                       = "OAC for ${var.project_name} frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} frontend distribution"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class # PriceClass_100 for Free Tier (US, Canada, Europe)

  # Aliases (custom domain names)
  aliases = var.frontend_custom_domain != "" ? [var.frontend_custom_domain] : []

  # Origin: S3 Bucket
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Use Managed Cache Policy (CachingOptimized)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Use Managed Origin Request Policy (CORS-S3Origin)
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"

    # Use Managed Response Headers Policy (CORS-with-preflight-and-SecurityHeadersPolicy)
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
  }

  # Custom Error Responses (for SPA routing)
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL/TLS Configuration
  viewer_certificate {
    # Use custom domain certificate if provided
    acm_certificate_arn      = var.frontend_custom_domain != "" ? var.frontend_acm_certificate_arn : null
    ssl_support_method       = var.frontend_custom_domain != "" ? "sni-only" : null
    minimum_protocol_version = var.frontend_custom_domain != "" ? "TLSv1.2_2021" : null

    # Use default CloudFront certificate if no custom domain
    cloudfront_default_certificate = var.frontend_custom_domain == "" ? true : null
  }

  # Logging (optional)
  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging ? [1] : []
    content {
      bucket = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
      prefix = "cloudfront/"
    }
  }

  tags = {
    Name = "${var.project_name}-frontend-distribution-${var.environment}"
  }
}

# S3 Bucket Policy to allow CloudFront OAC access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# S3 Bucket for CloudFront Logs (optional)
resource "aws_s3_bucket" "cloudfront_logs" {
  count  = var.enable_cloudfront_logging ? 1 : 0
  bucket = "${var.project_name}-cloudfront-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-cloudfront-logs-${var.environment}"
  }
}

# S3 Bucket Ownership Controls for CloudFront Logs
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count  = var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Bucket ACL for CloudFront Logs
resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count      = var.enable_cloudfront_logging ? 1 : 0
  bucket     = aws_s3_bucket.cloudfront_logs[0].id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

# S3 Bucket Lifecycle Rule for CloudFront Logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count  = var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = var.cloudfront_logs_retention_days
    }
  }
}
