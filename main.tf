locals {
  # Computed rather than read from module.ecs outputs, so the ecs and
  # monitoring modules don't form a dependency cycle (ecs needs the log
  # group up front; monitoring's alarms need the cluster/service names).
  ecs_cluster_name = "${var.project_name}-${var.environment}-cluster"
  ecs_service_name = "${var.project_name}-${var.environment}-api"
}

module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "./modules/iam"

  project_name     = var.project_name
  environment      = var.environment
  bedrock_model_id = var.bedrock_model_id
  sns_topic_arn    = module.notifications.sns_topic_arn
}

# SNS -> SQS -> a small, dependency-free Lambda -> SES. Declared here,
# after iam, but referenced BY iam above -- Terraform resolves this by
# each resource's own real dependencies, not by where a module happens
# to be written in this file (same reasoning already applied to the
# lambda/apigateway pair below).
module "notifications" {
  source = "./modules/notifications"

  project_name                     = var.project_name
  environment                      = var.environment
  ses_sender_email                 = var.ses_sender_email
  notification_lambda_source_path  = var.notification_lambda_source_path
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.ecs_cluster_name
  service_name = local.ecs_service_name
}

# Step 3 of the original AWS learning plan: Lambda + Mangum, running
# alongside the ECS service above, not replacing it yet. A second ECR
# repo (repo_suffix = "lambda") since this is a genuinely different
# image -- built from Dockerfile.lambda against AWS's own Lambda
# Python base image, not the plain python:3.12-slim image the ECS
# repo holds.
module "ecr_lambda" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  repo_suffix  = "lambda"
}

# Declared before the lambda module below despite lambda needing this
# module's execution_arn output -- Terraform resolves this by resource,
# not by declaration order or module nesting: aws_apigatewayv2_api.this
# has no dependency on anything in the lambda module, so it can be
# created independently, and the lambda module's aws_lambda_permission
# resource (the one that actually needs execution_arn) simply waits
# for it. Not a circular dependency -- see modules/lambda/main.tf's own
# comment for why.
module "apigateway" {
  source = "./modules/apigateway"

  project_name      = var.project_name
  environment       = var.environment
  lambda_invoke_arn = module.lambda.invoke_arn
}

module "lambda" {
  source = "./modules/lambda"

  project_name              = var.project_name
  environment               = var.environment
  container_image           = var.lambda_container_image
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  apigateway_execution_arn  = module.apigateway.execution_arn

  # Same values the ecs module already receives -- both deployment
  # paths need to behave identically to the frontend and to Plaid,
  # since they're meant to be interchangeable (the whole point of
  # running them side by side is comparing them, not two apps that
  # happen to share a name).
  cors_origins             = var.frontend_origin
  clerk_authorized_parties = var.frontend_origin
  plaid_env                = var.plaid_env
  bedrock_model_id         = var.bedrock_model_id
  sns_topic_arn            = module.notifications.sns_topic_arn
  # Was module.alb.alb_dns_name -- the ALB it pointed at is gone
  # (manually deleted along with ECS). API Gateway's own endpoint is
  # now the only real place Plaid should send webhooks. trimsuffix
  # guards against api_endpoint's own trailing slash (confirmed
  # present in the real applied output) producing a double slash here
  # -- the exact same class of bug that broke SANCHAY_API_ORIGIN once
  # already this session.
  plaid_webhook_url = "${trimsuffix(module.apigateway.api_endpoint, "/")}/api/v1/plaid/webhook"
}
