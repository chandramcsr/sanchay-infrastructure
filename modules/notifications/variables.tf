variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "ses_sender_email" {
  description = "The verified SES sender identity -- must be verified in the SES console before this actually sends (SES sandbox also restricts recipients to verified addresses until production access is granted)"
  type        = string
}

variable "notification_lambda_source_path" {
  description = "Local path to sanchay-api's app/notification_processor.py -- zipped by Terraform itself at apply time, no separate build/push step needed (unlike the container-image API Lambda)"
  type        = string
}
