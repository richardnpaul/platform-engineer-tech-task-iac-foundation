include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on organizations stack to get account IDs
dependency "orgs" {
  config_path = "../../organizations"

  mock_outputs = {
    deployment_account_id  = "123456789012"
    log_archive_account_id = "123456789013"
    audit_account_id       = "123456789014"
  }
}

locals {
  environment = get_env("TF_VAR_environment")
  aws_region  = get_env("TF_VAR_region", "eu-west-1")

  tags = {
    Environment  = local.environment
    ManagedBy    = "Terragrunt"
    Stack        = "github-oidc"
    Project      = "iac-foundation"
    Account      = "Management"
  }
}

terraform {
  source = "${get_repo_root()}/modules/aws/github-oidc"
}

inputs = {
  github_org  = "richardnpaul"
  github_repo = "platform-engineer-tech-task-iac-foundation"

  # Environment-based authentication with restrictions:
  # - production: only from main branch
  # - dev/staging: only from pull requests
  # - main branch: direct push access
  allow_legacy_pull_request = false

  role_name        = "GitHubActionsDeploymentRole"
  session_duration = 14400 # 4 hours

  # S3 bucket for Terraform state
  state_bucket_name = "iac-foundation-tf-state"

  # External ID for cross-account role assumption (change this to a secure random value)
  external_id = "github-actions-deployment-2025"

  # Target accounts where GitHub Actions can deploy
  # TODO: Make this dynamic with dependencies once Terragrunt supports it better
  target_account_ids = [
    "515048895906",  # deployment
    "249127818770",  # log-archive
    "102663704257"   # audit
  ]

  tags = local.tags
}
