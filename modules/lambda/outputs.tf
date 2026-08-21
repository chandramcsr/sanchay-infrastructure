output "function_arn" {
  value = aws_lambda_function.api.arn
}

output "invoke_arn" {
  # Distinct from function_arn -- this is the specific format API
  # Gateway's Lambda proxy integration needs (an arn:aws:apigateway:...
  # wrapper around the function ARN), not just the function's own ARN.
  value = aws_lambda_function.api.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}
