output "function_name" {
  value = aws_lambda_function.hello.function_name
}

output "function_arn" {
  value = aws_lambda_function.hello.arn
}

output "invoke_arn" {
  value = aws_lambda_function.hello.invoke_arn
}
