variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "container_image" {
  description = "Full image URI in the Lambda-specific ECR repo (built from Dockerfile.lambda, not the ECS Dockerfile)"
  type        = string
}

variable "lambda_execution_role_arn" {
  type = string
}

variable "apigateway_execution_arn" {
  description = "The API Gateway's own execution ARN, used to scope the Lambda invoke permission to this specific API rather than any API Gateway in the account"
  type        = string
}

variable "memory_size" {
  type    = number
  default = 512
}

variable "cors_origins" {
  type = string
}

variable "clerk_authorized_parties" {
  type = string
}

variable "plaid_env" {
  type    = string
  default = "sandbox"
}

variable "plaid_webhook_url" {
  type = string
}

variable "bedrock_model_id" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}
