include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "production"
  aws_region  = "eu-west-1"

  # Get organization root ID
  # Use profile in local dev, default credentials in CI/CD (OIDC)
  aws_profile_arg = get_env("CI", "") == "" ? "--profile terraform-bootstrap" : ""
  organization_root_id = run_cmd("--terragrunt-quiet", "bash", "-c", "aws organizations list-roots ${local.aws_profile_arg} --query 'Roots[0].Id' --output text")

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
  organization_root_id = local.organization_root_id
  environment          = local.environment
  tags                 = local.tags

  # Core account email addresses
  # Note: These must be unique across ALL AWS accounts globally
  # Set these via environment variables: TF_VAR_log_archive_email, TF_VAR_audit_email, TF_VAR_deployment_email
  log_archive_email = get_env("TF_VAR_log_archive_email", "example+log-archive@example.com")
  audit_email       = get_env("TF_VAR_audit_email", "example+audit@example.com")
  deployment_email  = get_env("TF_VAR_deployment_email", "example+deployment@example.com")
}
