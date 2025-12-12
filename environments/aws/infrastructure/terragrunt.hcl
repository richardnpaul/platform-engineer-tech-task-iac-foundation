# Multi-Environment Infrastructure Stack
#
# Single Terragrunt configuration that works across all environments
# Environment-specific values come from:
# 1. GitHub environment variables (in CI/CD)
# 2. Local .tfvars files (for local dev)
# 3. Environment variables (TF_VAR_*)
#
# Benefits:
# - DRY: One configuration for all environments
# - Consistent: Same code path for dev/staging/prod
# - Scalable: Add new environments without new folders
# - Simple: No environment-specific logic

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # Environment name comes from environment variable
  # In CI/CD: Set via GitHub environment
  # Locally: export TF_VAR_environment=dev
  environment = get_env("TF_VAR_environment", "dev")

  # Region can also be environment-specific
  region = get_env("TF_VAR_region", "eu-west-1")

  # Base tags applied to all resources
  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Project     = "platform-foundation"
  }
}

terraform {
  source = "${get_repo_root()}//modules/aws/dev-infrastructure"
}# All inputs come from variables - no hardcoded environment values
inputs = {
  environment = local.environment
  region      = local.region

  # These will come from tfvars files or TF_VAR_* environment variables
  # vpc_cidr = set via tfvars
  # eks_mgmt_cluster_name = set via tfvars
  # eks_apps_cluster_name = set via tfvars
  # kubernetes_version = set via tfvars

  tags = local.tags
}
