terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # No remote backend configured yet — state is local for now.
  # Add an S3 + DynamoDB backend block here once you're ready to
  # share state / lock it (each environment can point at its own key).
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "sanchay"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
