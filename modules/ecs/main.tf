resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

# Neon Postgres connection string, read from SSM Parameter Store and
# injected into the container rather than passed as a plain env var.
data "aws_ssm_parameter" "database_url" {
  name = "/sanchay-api/database-url"
}

# The other five secrets sanchay-api reads at startup -- all missing
# from the original module entirely, meaning Clerk auth verification,
# the Clerk user.deleted webhook, Plaid account data, and Plaid's
# encrypted access tokens (field_encryption_key) had nothing real to
# read and would have failed the moment a request actually exercised
# any of them.
data "aws_ssm_parameter" "clerk_jwt_key" {
  name = "/sanchay-api/clerk-jwt-key"
}

data "aws_ssm_parameter" "clerk_webhook_secret" {
  name = "/sanchay-api/clerk-webhook-secret"
}

data "aws_ssm_parameter" "field_encryption_key" {
  name = "/sanchay-api/field-encryption-key"
}

data "aws_ssm_parameter" "plaid_client_id" {
  name = "/sanchay-api/plaid-client-id"
}

data "aws_ssm_parameter" "plaid_secret" {
  name = "/sanchay-api/plaid-secret"
}

resource "aws_security_group" "tasks" {
  name        = "${var.project_name}-${var.environment}-tasks-sg"
  description = "Allow inbound from the ALB to sanchay-api tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tasks-sg"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-${var.environment}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-api"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      # Overrides the image's own default CMD (start.sh, which runs
      # `alembic upgrade head` before starting uvicorn). Without this,
      # every task that starts -- and Fargate can start more than one
      # at a time, on any deployment or scale-out -- races the same
      # migration concurrently. start.sh's own comments already
      # document why this matters; this task definition just wasn't
      # honoring it. Migrations are handled by CI instead.
      command = ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", tostring(var.container_port)]
      environment = [
        { name = "CORS_ORIGINS", value = var.cors_origins },
        { name = "CLERK_AUTHORIZED_PARTIES", value = var.clerk_authorized_parties },
        { name = "PLAID_ENV", value = var.plaid_env },
        { name = "PLAID_WEBHOOK_URL", value = var.plaid_webhook_url },
        { name = "BEDROCK_MODEL_ID", value = var.bedrock_model_id },
        # Reuses the SAME data source already used below for the log
        # group's own region, rather than a separate hardcoded value --
        # this way AWS_REGION always matches wherever the task is
        # actually running, not a value someone has to remember to
        # keep in sync if this is ever deployed somewhere else.
        { name = "AWS_REGION", value = data.aws_region.current.name },
      ]
      secrets = [
        {
          # The app reads this as SANCHAY_APP_DATABASE_URL, not
          # DATABASE_URL (checked directly against config.py -- no
          # alias is set on that field, so pydantic-settings only
          # matches the exact uppercased name). The previous name here
          # meant the app never saw this value at all, and silently
          # fell back to its own SQLite default instead of erroring --
          # every deploy so far has been running against a throwaway
          # local database, not Neon.
          name      = "SANCHAY_APP_DATABASE_URL"
          valueFrom = data.aws_ssm_parameter.database_url.arn
        },
        {
          name      = "CLERK_JWT_KEY"
          valueFrom = data.aws_ssm_parameter.clerk_jwt_key.arn
        },
        {
          name      = "CLERK_WEBHOOK_SECRET"
          valueFrom = data.aws_ssm_parameter.clerk_webhook_secret.arn
        },
        {
          name      = "FIELD_ENCRYPTION_KEY"
          valueFrom = data.aws_ssm_parameter.field_encryption_key.arn
        },
        {
          name      = "PLAID_CLIENT_ID"
          valueFrom = data.aws_ssm_parameter.plaid_client_id.arn
        },
        {
          name      = "PLAID_SECRET"
          valueFrom = data.aws_ssm_parameter.plaid_secret.arn
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

data "aws_region" "current" {}

resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "${var.project_name}-api"
    container_port   = var.container_port
  }
}
