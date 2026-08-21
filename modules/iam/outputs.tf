output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}
