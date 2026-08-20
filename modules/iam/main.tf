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
# parameters — needed so the task can fetch DATABASE_URL from SSM Parameter Store.
data "aws_iam_policy_document" "read_parameters" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/sanchay-api/database-url"]
  }
}

resource "aws_iam_role_policy" "execution_read_parameters" {
  name   = "${var.project_name}-${var.environment}-read-parameters"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_parameters.json
}

# Task role: permissions the running sanchay-api application itself needs.
# Empty for now — attach policies here as the app needs to call other AWS services.
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}
