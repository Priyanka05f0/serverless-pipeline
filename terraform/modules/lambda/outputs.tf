output "function_name" {
  value = aws_lambda_function.hello.function_name
}

output "function_arn" {
  value = aws_lambda_function.hello.arn
}

output "invoke_arn" {
  value = aws_lambda_function.hello.invoke_arn
}

output "function_version" {
  value = aws_lambda_function.hello.version
}

output "blue_alias_arn" {
  value = var.enable_blue_green ? aws_lambda_alias.blue[0].arn : null
}

output "green_alias_arn" {
  value = var.enable_blue_green ? aws_lambda_alias.green[0].arn : null
}
