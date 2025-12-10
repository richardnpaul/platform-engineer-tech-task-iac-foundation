include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/aws/s3-bucket"
}

locals {
  environment = "root"
  aws_region  = get_env("AWS_REGION", "eu-west-1")  # Same region as state bucket
}

inputs = {
  bucket_name        = "iac-foundation-tf-plans"
  versioning_enabled = false  # No versioning needed for plans
  force_destroy      = true   # Allow cleanup in dev/test

  lifecycle_rules = [
    {
      id      = "cleanup-old-plans"
      enabled = true
      prefix  = ""  # Apply to all objects
      expiration_days = 14  # Delete after 2 weeks
      abort_incomplete_multipart_upload_days = 1
    }
  ]

  tags = {
    Name        = "iac-foundation-tf-plans"
    Purpose     = "Terraform plan storage for CI/CD"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Repository  = "platform-engineer-tech-task-iac-foundation"
    Lifecycle   = "14-days"
  }
}
