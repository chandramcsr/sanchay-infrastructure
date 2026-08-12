environment   = "prod"
aws_region    = "us-east-2"
project_name  = "sanchay"

# Matches what's currently running by hand in account 263011180772:
# ECS Fargate + ALB, no NAT Gateway, no Route 53 / custom domain yet.
desired_count = 1
task_cpu      = 256
task_memory   = 512

# container_image and database_url are secrets/build-specific — pass at apply time.
# See environments/dev/terraform.tfvars for the exact command.
