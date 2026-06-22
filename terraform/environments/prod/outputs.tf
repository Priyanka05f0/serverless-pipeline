output "active_slot" {
  value       = var.active_slot
  description = "Currently active deployment slot"
}

output "invoke_url" {
  value       = module.api_gateway.invoke_url
  description = "API Gateway invoke URL"
}

output "blue_lambda_name" {
  value = module.lambda_blue.function_name
}

output "green_lambda_name" {
  value = module.lambda_green.function_name
}
