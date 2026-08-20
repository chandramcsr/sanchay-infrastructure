environment  = "dev"
aws_region   = "us-east-2"
project_name = "sanchay"

desired_count = 1
task_cpu      = 256
task_memory   = 512

# container_image is build-specific — pass it at apply time, e.g.:
#   terraform apply -var-file=environments/dev/terraform.tfvars \
#     -var="container_image=<account>.dkr.ecr.us-east-2.amazonaws.com/sanchay-dev-api:latest"
# The database URL is read directly from SSM Parameter Store at
# /sanchay-api/database-url — populate it there before deploying.
