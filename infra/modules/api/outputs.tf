output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.visitors.invoke_url}/visitors"
}

output "lambda_function_name" {
  value = aws_lambda_function.visitors.function_name
}

output "api_id" {
  value = aws_apigatewayv2_api.visitors.id
}
