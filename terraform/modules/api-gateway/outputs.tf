output "api_id" {
  value = aws_api_gateway_rest_api.hello_api.id
}

output "invoke_url" {
  value = "${aws_api_gateway_stage.hello.invoke_url}/hello"
}

output "stage_name" {
  value = aws_api_gateway_stage.hello.stage_name
}

output "api_key_value" {
  value     = var.use_api_key ? aws_api_gateway_api_key.hello[0].value : null
  sensitive = true
}
