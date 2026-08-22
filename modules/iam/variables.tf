variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for Ask Sanchay -- the cross-region inference profile ID (e.g. us.meta.llama4-scout-17b-instruct-v1:0), not the bare foundation-model ID"
  type        = string
}

variable "sns_topic_arn" {
  description = "The sanchay-events SNS topic's ARN (from the notifications module) -- both the ECS task role and the API Lambda's execution role need sns:Publish on this"
  type        = string
}
