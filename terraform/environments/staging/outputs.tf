output "invoke_url" {
  value       = module.api_gateway.invoke_url
  description = "API Gateway invoke URL for staging"
}

output "lambda_function_name" {
  value = module.lambda.function_name
}
