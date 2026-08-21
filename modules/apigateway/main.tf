# HTTP API (API Gateway v2), not REST API (v1) -- roughly 70% cheaper
# per AWS's own published pricing, and this app doesn't need any REST-
# API-specific feature (request validation templates, WAF's native
# integration, usage plans) that would justify the extra cost. This is
# also the piece of the original learning plan being picked up here
# (Step 4), separately from the choice to use Lambda's own Function
# URL instead, which was considered and deliberately not chosen for
# that reason.

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
}

# A single Lambda proxy integration, not one per route -- sanchay-api
# is a full FastAPI app with many endpoints already, and Mangum
# (app/lambda_handler.py) is what actually routes a request to the
# right FastAPI path internally. API Gateway's job here is just to
# get every request to the Lambda at all, not to know about the app's
# own routes -- that's what the $default catch-all route below does.
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# $default is API Gateway's own catch-all -- matches ANY method on ANY
# path with no route table to maintain here as new FastAPI endpoints
# get added. The alternative (a route per endpoint, e.g. "GET
# /api/v1/accounts") would mean updating this Terraform every time a
# new route is added to the app, which defeats the point of routing
# already being handled by FastAPI/Mangum one layer down.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}
