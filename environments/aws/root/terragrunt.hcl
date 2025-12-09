locals {
  environment = "root"
  aws_region  = get_env("AWS_REGION", "eu-west-1")
  tags = {
    Environment = local.environment
    Project     = "iac-foundation"
    ManagedBy   = "terragrunt"
  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/aws/foundation"
}

inputs = {
  environment = local.environment
  aws_region  = local.aws_region
  tags        = local.tags
}
