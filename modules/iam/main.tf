data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: lets ECS pull the image from ECR and write logs to CloudWatch.
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-${var.environment}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed policy above covers ECR pull + log creation, but not reading
# parameters — needed so the task can fetch its secrets from SSM Parameter
# Store. Scoped to the whole /sanchay-api/* prefix, not one parameter at a
# time — every secret the app needs (database URL, Clerk keys, Plaid keys,
# the field encryption key) lives under this same prefix, and the app reads
# all of them at startup, not just one.
data "aws_iam_policy_document" "read_parameters" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/sanchay-api/*"]
  }
}

resource "aws_iam_role_policy" "execution_read_parameters" {
  name   = "${var.project_name}-${var.environment}-read-parameters"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_parameters.json
}

# Task role: permissions the running sanchay-api application itself needs.
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

# Needed to build the exact ARNs below -- account ID and region come
# from whoever/wherever this is actually being applied, not hardcoded,
# so this stays portable across accounts/regions rather than only
# working for the specific account this was first written against.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Ask Sanchay's Bedrock access. Only two permission-relevant details
# here, both confirmed against AWS's own documentation before writing
# this, not assumed:
#
# 1. This app runs in us-east-2, which is NOT one of Llama 4's two
#    natively-hosted regions (us-east-1/us-west-2) -- var.bedrock_model_id
#    is therefore the CROSS-REGION INFERENCE PROFILE id (the "us."
#    prefix), not the bare foundation-model id. Calling it any other
#    way fails outright from this region.
#
# 2. Because it's a cross-region profile, Bedrock can route the actual
#    inference call to any of the three regions it spans -- so the
#    IAM policy needs the underlying foundation-model ARN granted in
#    ALL THREE regions (confirmed against a real reported failure
#    where granting only the home region caused AccessDenied whenever
#    Bedrock happened to route elsewhere), plus the inference-profile
#    ARN itself in the region this is actually deployed to.
#
# trimprefix strips the profile's "us." so the same variable drives
# both the foundation-model ARNs here AND the app's own
# BEDROCK_MODEL_ID env var (see the ecs module) -- one source, not two
# independently-typed values that could quietly drift apart the way
# cors_origins/clerk_authorized_parties already did once.
locals {
  bedrock_foundation_model_id = trimprefix(var.bedrock_model_id, "us.")
  bedrock_cross_regions       = ["us-east-1", "us-east-2", "us-west-2"]
}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    sid       = "InvokeFoundationModelAcrossCrossRegionProfile"
    actions   = ["bedrock:InvokeModel", "bedrock:Converse", "bedrock:ConverseStream"]
    resources = [for r in local.bedrock_cross_regions : "arn:aws:bedrock:${r}::foundation-model/${local.bedrock_foundation_model_id}"]
  }
  statement {
    sid       = "InvokeCrossRegionInferenceProfile"
    actions   = ["bedrock:InvokeModel", "bedrock:Converse", "bedrock:ConverseStream"]
    resources = ["arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}"]
  }
}

resource "aws_iam_role_policy" "task_bedrock_invoke" {
  name   = "${var.project_name}-${var.environment}-bedrock-invoke"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}

# Lambda execution role -- for the Step-3 Lambda+Mangum path, running
# alongside ECS. A genuinely different trust policy from the ECS roles
# above (lambda.amazonaws.com assumes this, not ecs-tasks.amazonaws.com),
# so it can't just reuse aws_iam_role.execution/task even though the
# PERMISSIONS it needs largely overlap -- reads the same secrets,
# calls the same Bedrock model.
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-${var.environment}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# AWS-managed policy covering CloudWatch Logs write access -- the
# Lambda equivalent of what AmazonECSTaskExecutionRolePolicy covers
# for the ECS execution role above, just without the ECR-pull
# permission ECS needs and Lambda container images pull differently
# (via the Lambda service itself, not this role).
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Same policy documents already built for the ECS task role above --
# reused here rather than redefining the same SSM prefix and Bedrock
# ARNs a second time for a role that needs identical access to the
# identical resources.
resource "aws_iam_role_policy" "lambda_read_parameters" {
  name   = "${var.project_name}-${var.environment}-lambda-read-parameters"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.read_parameters.json
}

resource "aws_iam_role_policy" "lambda_bedrock_invoke" {
  name   = "${var.project_name}-${var.environment}-lambda-bedrock-invoke"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}
