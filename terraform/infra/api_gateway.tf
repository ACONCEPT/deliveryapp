# API Gateway HTTP API (v2) with Lambda Proxy Integration
# HTTP API is cheaper and simpler than REST API, perfect for Lambda proxy

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "HTTP API for ${var.project_name} backend"

  # CORS is handled by the Lambda application (CORSMiddleware in Go)
  # DO NOT configure CORS here - it conflicts with Lambda proxy integration
  # The Lambda returns proper CORS headers for all requests including OPTIONS

  tags = {
    Name = "${var.project_name}-api-${var.environment}"
  }
}

# Integration with Lambda function (proxy integration)
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.main.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.backend.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"

  # Timeout (max 30 seconds for HTTP API)
  timeout_milliseconds = var.api_gateway_timeout_ms
}

# Default route (catch-all for proxy integration)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage for API Gateway
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.api_gateway_burst_limit
    throttling_rate_limit  = var.api_gateway_rate_limit
  }

  tags = {
    Name = "${var.project_name}-api-stage-${var.environment}"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.api_gateway_log_retention_days

  tags = {
    Name = "${var.project_name}-api-gateway-logs-${var.environment}"
  }
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Custom domain name (optional)
resource "aws_apigatewayv2_domain_name" "main" {
  count       = var.api_custom_domain != "" ? 1 : 0
  domain_name = var.api_custom_domain

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = {
    Name = "${var.project_name}-api-domain-${var.environment}"
  }
}

# API Mapping for custom domain
resource "aws_apigatewayv2_api_mapping" "main" {
  count       = var.api_custom_domain != "" ? 1 : 0
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.main[0].id
  stage       = aws_apigatewayv2_stage.default.id
}
