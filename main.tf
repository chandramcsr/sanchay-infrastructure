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
}

module "alb" {
  source = "./modules/alb"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  public_subnets = module.networking.public_subnet_ids
  container_port = var.container_port
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnets        = module.networking.public_subnet_ids
  container_image       = var.container_image
  container_port        = var.container_port
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arn
  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  log_group_name        = module.monitoring.log_group_name
  cluster_name          = local.ecs_cluster_name
  service_name          = local.ecs_service_name

  # Both derived from the same variable rather than two independent
  # ones -- these have always needed to be identical in practice (the
  # Amplify frontend's own origin), and a single source makes that
  # impossible to get out of sync by editing one and forgetting the
  # other.
  cors_origins             = var.frontend_origin
  clerk_authorized_parties = var.frontend_origin
  plaid_env                = var.plaid_env
  bedrock_model_id         = var.bedrock_model_id
  # Computed directly from the ALB module's own output, not a
  # separate variable the user would need to already know (and
  # manually keep in sync) before the ALB itself is created.
  plaid_webhook_url = "http://${module.alb.alb_dns_name}/api/v1/plaid/webhook"
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
  plaid_webhook_url        = "http://${module.alb.alb_dns_name}/api/v1/plaid/webhook"
}
