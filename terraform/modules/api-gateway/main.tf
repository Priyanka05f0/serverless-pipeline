resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "${var.api_name}"
  description = "Hello API for ${var.environment} environment"
  tags        = var.tags
}

resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "get_hello" {
  rest_api_id      = aws_api_gateway_rest_api.hello_api.id
  resource_id      = aws_api_gateway_resource.hello.id
  http_method      = "GET"
  authorization    = var.use_api_key ? "NONE" : "NONE"
  api_key_required = var.use_api_key
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.hello_api.id
  resource_id             = aws_api_gateway_resource.hello.id
  http_method             = aws_api_gateway_method.get_hello.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# CORS OPTIONS method
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "hello" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  depends_on  = [aws_api_gateway_integration.lambda, aws_api_gateway_integration.options]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.hello.id,
      aws_api_gateway_method.get_hello.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "hello" {
  deployment_id = aws_api_gateway_deployment.hello.id
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  stage_name    = var.stage_name

  tags = var.tags
}

# API Key (optional - for prod security)
resource "aws_api_gateway_api_key" "hello" {
  count = var.use_api_key ? 1 : 0
  name  = "${var.api_name}-key"
  tags  = var.tags
}

resource "aws_api_gateway_usage_plan" "hello" {
  count = var.use_api_key ? 1 : 0
  name  = "${var.api_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.hello_api.id
    stage  = aws_api_gateway_stage.hello.stage_name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 200
  }

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "hello" {
  count         = var.use_api_key ? 1 : 0
  key_id        = aws_api_gateway_api_key.hello[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.hello[0].id
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*"
}
