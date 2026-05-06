output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.visitors.invoke_url}/visitors"
}
