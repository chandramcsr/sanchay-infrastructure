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

variable "container_image" {
  description = "Full ECR image URI (repo:tag) for the sanchay-api container"
  type        = string
}

variable "container_port" {
  description = "Port the sanchay-api container listens on"
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of running ECS tasks"
  type        = number
  default     = 1
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
