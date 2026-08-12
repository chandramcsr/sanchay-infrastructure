# sanchay-infrastructure

Terraform for the AWS infrastructure backing `sanchay-api`: ECS Fargate behind
an Application Load Balancer, pulling images from ECR, in a public-subnet-only
VPC (no NAT Gateway, no Route 53 domain yet — both deferred to keep monthly
cost near zero).

## Structure

- `modules/` — one module per concern: `networking`, `ecr`, `iam`, `alb`,
  `ecs`, `monitoring`.
- `main.tf` / `variables.tf` / `outputs.tf` / `providers.tf` — the root
  configuration that wires the modules together.
- `environments/{dev,staging,prod}/terraform.tfvars` — per-environment
  variable values. Each environment shares the root config but should use
  its own state (see below).

## Usage

Each environment needs its own state so `dev`/`staging`/`prod` don't collide.
Until a remote backend (S3 + DynamoDB) is added, use a separate local state
file per environment:

```bash
terraform init

terraform apply \
  -var-file=environments/prod/terraform.tfvars \
  -var="container_image=<account-id>.dkr.ecr.us-east-2.amazonaws.com/sanchay-prod-api:latest" \
  -var="database_url=$DATABASE_URL" \
  -state=environments/prod/terraform.tfstate
```

Swap the `-var-file` and `-state` paths for `dev` or `staging`.

`container_image` and `database_url` are passed at apply time rather than
committed to a `.tfvars` file, since one's build-specific and the other's a
secret.

## Current gaps

- No remote state backend yet — state is local, one file per environment.
- No HTTPS/ACM cert — traffic to the ALB is HTTP-only until there's a real
  domain.
- `iam`'s task role has no policies attached yet; add them as sanchay-api
  starts calling other AWS services directly.
