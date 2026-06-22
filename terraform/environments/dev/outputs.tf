output "invoke_url" {
  value       = module.api_gateway.invoke_url
  description = "API Gateway invoke URL for dev"
}

output "lambda_function_name" {
  value = module.lambda.function_name
}
