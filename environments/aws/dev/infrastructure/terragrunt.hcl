# Dev Infrastructure Stack
#
# Single stack containing all dev environment infrastructure:
# - VPC with public/private subnets and ALB
# - EKS Management cluster (ArgoCD)
# - EKS Apps cluster (workloads)
#
# Benefits:
# - Single deployment (no dependency orchestration)
# - No hardcoded IDs (direct Terraform references)
# - Atomic changes (all or nothing)
# - Simpler CI/CD (one plan, one apply)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "dev"
  region      = "eu-west-1"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "platform-foundation"
  }
}

terraform {
  source = "../../../../modules/aws/dev-infrastructure"
}

inputs = {
  environment = local.environment
  region      = local.region

  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"

  # EKS Configuration
  eks_mgmt_cluster_name = "dev-mgmt-cluster"
  eks_apps_cluster_name = "dev-apps-cluster"
  kubernetes_version    = "1.31"

  tags = local.tags
}
