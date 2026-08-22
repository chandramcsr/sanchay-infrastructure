output "alb_dns_name" {
  description = "Public DNS name of the ALB fronting sanchay-api"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL to push sanchay-api images to"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "lambda_ecr_repository_url" {
  description = "ECR repository URL to push the Lambda-packaged sanchay-api image to (built from Dockerfile.lambda, a different image from ecr_repository_url above)"
  value       = module.ecr_lambda.repository_url
}

output "api_gateway_endpoint" {
  description = "Invoke URL for the API Gateway + Lambda path -- test this directly against sanchay-api, separate from alb_dns_name, to compare the two before any frontend cutover"
  value       = module.apigateway.api_endpoint
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "sns_topic_arn" {
  description = "Publish target for future event types beyond BudgetExceeded"
  value       = module.notifications.sns_topic_arn
}

output "notification_processor_function_name" {
  value = module.notifications.notification_processor_function_name
}

output "notification_dlq_url" {
  description = "Check here for BudgetExceeded events that failed processing repeatedly"
  value       = module.notifications.notification_dlq_url
}
