environment  = "staging"
aws_region   = "us-east-2"
project_name = "sanchay"

desired_count = 1
task_cpu      = 256
task_memory   = 512

# container_image is build-specific — pass at apply time.
# See environments/dev/terraform.tfvars for the exact command.
# The database URL is read directly from SSM Parameter Store at
# /sanchay-api/database-url — populate it there before deploying.
