terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {}
}

locals {
  placeholder_summary = "Module scaffold for ${var.environment} in ${var.aws_region}"
}

# No AWS resources yet; this module only demonstrates the Terragrunt wiring.
