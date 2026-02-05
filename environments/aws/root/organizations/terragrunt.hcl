include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "production"
  aws_region  = get_env("AWS_REGION", "eu-west-1")

  tags = {
    Environment  = local.environment
    ManagedBy    = "Terragrunt"
    Stack        = "organizations"
    Project      = "iac-foundation"
  }
}

terraform {
  source = "${get_repo_root()}/modules/aws/organizations"
}

inputs = {
  environment = local.environment
  tags        = local.tags

  # Core account email addresses
  # Note: These must be unique across ALL AWS accounts globally
  # Set these via environment variables in Github Actions:
  #   - TF_VAR_log_archive_email
  #   - TF_VAR_audit_email
  #   - TF_VAR_deployment_email
  log_archive_email = get_env("TF_VAR_log_archive_email", "example+log-archive@example.com")
  audit_email       = get_env("TF_VAR_audit_email", "example+audit@example.com")
  deployment_email  = get_env("TF_VAR_deployment_email", "example+deployment@example.com")
}
