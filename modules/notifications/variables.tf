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
  description = "Local path to sanchay-api's app/notification_processor.py -- zipped by Terraform itself at apply time (now bundled with its own OTel dependencies via a build step, see main.tf's null_resource)"
  type        = string
}

variable "otel_exporter_otlp_endpoint" {
  description = "Grafana Cloud (or any OTLP-compatible backend)'s OTLP endpoint -- empty string when not yet configured, treated as absent by the app's own gating logic (os.environ.get(...) on an empty string is falsy)"
  type        = string
  default     = ""
}

variable "otel_exporter_otlp_headers" {
  description = "OTLP auth headers, e.g. Grafana Cloud's Basic auth token -- empty string when not yet configured"
  type        = string
  default     = ""
  sensitive   = true
}
