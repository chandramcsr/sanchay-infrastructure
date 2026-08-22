# SNS "sanchay-events" topic -> SQS -> Lambda -> SES. A genuine
# general-purpose event bus (see sanchay-api's own
# notification_service.py docstring) -- BudgetExceeded is the first
# event type through it, not the only one this is built for.

resource "aws_sns_topic" "events" {
  name = "${var.project_name}-${var.environment}-events"
}

# Dead-letter queue -- a message that fails processing repeatedly
# (a malformed payload, SES rejecting an address, a bug) goes here
# after maxReceiveCount attempts instead of being silently dropped or
# retried forever. Nothing consumes this yet; it exists so failures
# are inspectable rather than invisible.
resource "aws_sqs_queue" "notification_dlq" {
  name = "${var.project_name}-${var.environment}-notification-dlq"
}

resource "aws_sqs_queue" "notification_queue" {
  name = "${var.project_name}-${var.environment}-notification-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })
}

# Lets the SNS topic actually deliver to this queue -- without this,
# the subscription below would be created successfully but every
# delivery attempt would fail silently with an access-denied SNS
# doesn't surface anywhere obvious. SQS requires the QUEUE's own
# policy to explicitly allow this, not just the subscription existing.
data "aws_iam_policy_document" "notification_queue_policy" {
  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    resources = [aws_sqs_queue.notification_queue.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notification_queue" {
  queue_url = aws_sqs_queue.notification_queue.id
  policy    = data.aws_iam_policy_document.notification_queue_policy.json
}

resource "aws_sns_topic_subscription" "notification_queue" {
  topic_arn = aws_sns_topic.events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_queue.arn
}

# --- Notification processor Lambda ---
# Deliberately zip-based, not a container image like the API Lambda --
# this function only needs boto3, which ships pre-installed in every
# AWS Lambda Python runtime, so there's no dependency to bundle and no
# Docker build/ECR push needed for this piece at all.

data "archive_file" "notification_processor" {
  type        = "zip"
  source_file = var.notification_lambda_source_path
  output_path = "${path.module}/notification_processor.zip"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notification_processor" {
  name               = "${var.project_name}-${var.environment}-notification-processor"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "notification_processor_basic_execution" {
  role       = aws_iam_role.notification_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS consume permissions, scoped to just this one queue -- not the
# managed AWSLambdaSQSQueueExecutionRole policy, which grants access
# to every queue in the account rather than just this function's own.
data "aws_iam_policy_document" "consume_notification_queue" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.notification_queue.arn]
  }
}

resource "aws_iam_role_policy" "notification_processor_consume_queue" {
  name   = "${var.project_name}-${var.environment}-consume-notification-queue"
  role   = aws_iam_role.notification_processor.id
  policy = data.aws_iam_policy_document.consume_notification_queue.json
}

# Scoped to the specific sender identity, not every SES resource in
# the account -- least-privilege, same discipline as the Bedrock
# policy's own scoped ARNs elsewhere in this repo.
data "aws_iam_policy_document" "send_via_ses" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/${var.ses_sender_email}"]
  }
}

resource "aws_iam_role_policy" "notification_processor_send_ses" {
  name   = "${var.project_name}-${var.environment}-send-via-ses"
  role   = aws_iam_role.notification_processor.id
  policy = data.aws_iam_policy_document.send_via_ses.json
}

resource "aws_lambda_function" "notification_processor" {
  function_name    = "${var.project_name}-${var.environment}-notification-processor"
  role             = aws_iam_role.notification_processor.arn
  filename         = data.archive_file.notification_processor.output_path
  source_code_hash = data.archive_file.notification_processor.output_base64sha256
  handler          = "notification_processor.handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      SES_SENDER_EMAIL = var.ses_sender_email
    }
  }
}

resource "aws_cloudwatch_log_group" "notification_processor" {
  name              = "/aws/lambda/${aws_lambda_function.notification_processor.function_name}"
  retention_in_days = 14
}

# Wires SQS to actually invoke the Lambda -- without this, messages
# would sit in the queue and the function would never run at all,
# regardless of the IAM permissions above being correct.
resource "aws_lambda_event_source_mapping" "notification_queue" {
  event_source_arn = aws_sqs_queue.notification_queue.arn
  function_name    = aws_lambda_function.notification_processor.arn
  batch_size       = 10
}
