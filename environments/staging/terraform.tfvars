environment   = "staging"
aws_region    = "us-east-2"
project_name  = "sanchay"

desired_count = 1
task_cpu      = 256
task_memory   = 512

# container_image and database_url are secrets/build-specific — pass at apply time.
# See environments/dev/terraform.tfvars for the exact command.
