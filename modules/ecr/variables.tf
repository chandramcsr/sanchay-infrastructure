variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "repo_suffix" {
  description = "Appended to project_name-environment- to form the repo name -- lets this module be called more than once for different images (e.g. the ECS image vs the Lambda image) without a naming collision"
  type        = string
  default     = "api"
}
