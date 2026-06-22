data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../lambda-src/hello_function"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "hello" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT = var.environment
      VERSION     = var.version
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda function errors > 0 for 5 minutes"

  dimensions = {
    FunctionName = aws_lambda_function.hello.function_name
  }

  tags = var.tags
}

# Lambda aliases for blue/green (used in prod)
resource "aws_lambda_alias" "blue" {
  count            = var.enable_blue_green ? 1 : 0
  name             = "blue"
  function_name    = aws_lambda_function.hello.function_name
  function_version = aws_lambda_function.hello.version
}

resource "aws_lambda_alias" "green" {
  count            = var.enable_blue_green ? 1 : 0
  name             = "green"
  function_name    = aws_lambda_function.hello.function_name
  function_version = aws_lambda_function.hello.version
}
