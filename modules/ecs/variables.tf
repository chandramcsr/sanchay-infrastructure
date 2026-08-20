variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

# The four PLAIN (non-secret) environment variables the app reads at
# startup — none of these existed as ECS module inputs before, so the
# app was running against every one of their code-level defaults
# (CORS_ORIGINS defaulting to "http://localhost:3000", meaning the
# real Amplify frontend couldn't reach this service at all).
variable "cors_origins" {
  description = "Comma-separated list of allowed CORS origins (the Amplify frontend's domain)"
  type        = string
}

variable "clerk_authorized_parties" {
  description = "Comma-separated list of Clerk authorized parties (same domain as cors_origins)"
  type        = string
}

variable "plaid_env" {
  description = "Plaid environment: sandbox or production"
  type        = string
  default     = "sandbox"
}

variable "plaid_webhook_url" {
  description = "Full URL sanchay-api should register with Plaid for transaction webhooks"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for Ask Sanchay -- the cross-region inference profile ID"
  type        = string
}
