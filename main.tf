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

  project_name = var.project_name
  environment  = var.environment
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
