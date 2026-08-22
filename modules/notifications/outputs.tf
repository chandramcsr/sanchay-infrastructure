output "sns_topic_arn" {
  description = "Pass this into the ecs and lambda modules' sns_topic_arn variable so the API can actually publish to it"
  value       = aws_sns_topic.events.arn
}

output "notification_processor_function_name" {
  value = aws_lambda_function.notification_processor.function_name
}

output "notification_dlq_url" {
  description = "Check here for messages that failed processing repeatedly"
  value       = aws_sqs_queue.notification_dlq.url
}
