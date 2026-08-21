output "execution_arn" {
  # Needed by the Lambda module's aws_lambda_permission resource, to
  # scope that permission to THIS specific API rather than any API
  # Gateway in the account -- a real security boundary, not just
  # bookkeeping.
  value = aws_apigatewayv2_api.this.execution_arn
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
