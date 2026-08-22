variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Short name used to prefix/tag resources"
  type        = string
  default     = "sanchay"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB + Fargate tasks, no NAT Gateway)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# The Amplify frontend's domain -- required, no default, since a
# wrong or missing value here means every real request gets blocked
# by CORS or Clerk token verification, not a loud error at apply time.
variable "frontend_origin" {
  description = "The Amplify frontend's full origin, e.g. https://main.xxxxx.amplifyapp.com -- used for both CORS_ORIGINS and CLERK_AUTHORIZED_PARTIES, which must match exactly"
  type        = string
}

variable "plaid_env" {
  description = "Plaid environment: sandbox or production"
  type        = string
  default     = "sandbox"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for Ask Sanchay -- the cross-region inference profile ID, not the bare foundation-model ID (this app doesn't run in one of Llama 4's two natively-hosted regions, so the bare ID fails outright)"
  type        = string
  default     = "us.meta.llama4-scout-17b-instruct-v1:0"
}

variable "otel_exporter_otlp_endpoint" {
  description = "OTLP endpoint for real trace export (Grafana Cloud or any OTLP-compatible backend) -- empty string until this is configured, treated as absent by the app's own gating logic"
  type        = string
  default     = ""
}

variable "otel_exporter_otlp_headers" {
  description = "OTLP auth headers -- empty string until configured"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ses_sender_email" {
  description = "Must be verified in the SES console before this actually sends -- SES also starts in sandbox mode, restricting recipients to verified addresses until production access is separately requested"
  type        = string
}

variable "notification_lambda_source_path" {
  description = "Local path to sanchay-api's app/notification_processor.py -- e.g. ../sanchay-api/app/notification_processor.py if both repos are cloned as siblings"
  type        = string
}

variable "lambda_container_image" {
  description = "Full ECR image URI (repo:tag) for the Lambda-packaged sanchay-api, built from Dockerfile.lambda -- a different image from container_image, which is built from the plain Dockerfile for ECS"
  type        = string
}
