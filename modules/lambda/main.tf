# Lambda function for the Step-3 Lambda+Mangum path -- running
# ALONGSIDE the existing ECS service for now (see the ecs module),
# not replacing it. Container image, not a zip package -- reuses the
# existing Dockerfile.lambda build (AWS's own Lambda Python base image
# with the Runtime Interface Client baked in), rather than fighting
# with zip-package native-dependency compatibility for psycopg2-binary
# and cryptography, which the ECS Dockerfile already had to solve once
# with a normal Linux base image.

data "aws_ssm_parameter" "database_url" {
  name = "/sanchay-api/database-url"
}

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

resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  role          = var.lambda_execution_role_arn
  package_type  = "Image"
  image_uri     = var.container_image

  # Matches API Gateway's own hard 29-second cap on HTTP APIs exactly
  # -- there's no benefit to Lambda allowing longer than API Gateway
  # will ever actually wait for, and setting it any higher would just
  # be misleading about how much time a request genuinely has.
  timeout     = 29
  memory_size = var.memory_size

  environment {
    variables = {
      CORS_ORIGINS              = var.cors_origins
      CLERK_AUTHORIZED_PARTIES  = var.clerk_authorized_parties
      PLAID_ENV                 = var.plaid_env
      PLAID_WEBHOOK_URL         = var.plaid_webhook_url
      BEDROCK_MODEL_ID          = var.bedrock_model_id
      # AWS_REGION is deliberately NOT set here -- it's a RESERVED
      # Lambda environment key (confirmed by a real apply failure:
      # "InvalidParameterValueException: ... reserved keys ... AWS_REGION"),
      # which Lambda refuses to let you override via Terraform or the
      # console. Nothing is lost by not setting it -- Lambda
      # automatically provides AWS_REGION to every function at
      # runtime, matching wherever it's actually deployed, so
      # settings.aws_region in the app reads the correct value with
      # zero configuration here.
      SANCHAY_APP_DATABASE_URL  = data.aws_ssm_parameter.database_url.value
      CLERK_JWT_KEY             = data.aws_ssm_parameter.clerk_jwt_key.value
      CLERK_WEBHOOK_SECRET      = data.aws_ssm_parameter.clerk_webhook_secret.value
      FIELD_ENCRYPTION_KEY      = data.aws_ssm_parameter.field_encryption_key.value
      PLAID_CLIENT_ID           = data.aws_ssm_parameter.plaid_client_id.value
      PLAID_SECRET              = data.aws_ssm_parameter.plaid_secret.value
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 14
}

# Grants API Gateway permission to actually invoke this function --
# without this, API Gateway's integration would be correctly
# configured but every real request would fail with an authorization
# error, since IAM doesn't implicitly trust API Gateway to call
# Lambda just because a route is wired up pointing at it.
resource "aws_lambda_permission" "apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.apigateway_execution_arn}/*/*"
}
