# Management EKS Cluster for ArgoCD
#
# Hosts ArgoCD for GitOps deployments to both clusters
# Uses shared VPC and ALB target group from vpc stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = get_env("TF_VAR_environment")
  region      = "eu-west-1"
  cluster     = "mgmt-cluster"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Purpose     = "argocd-management"
    Cluster     = local.cluster
    Project     = "platform-foundation"
  }
}

terraform {
  source = "../../../../modules/aws/eks"
}

inputs = {
  environment        = local.environment
  cluster_name       = local.cluster
  kubernetes_version = "1.34"

  vpc_name           = "shared-vpc"
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Environment" = local.environment
  }
  alb_target_group_name = "mgmt-tg"
  alb_name              = "shared-alb"

  # Fargate namespaces
  fargate_namespaces = [
    "default",
    "argocd"
  ]

  # Enable AWS Load Balancer Controller for ArgoCD ingress
  enable_aws_load_balancer_controller = true
  enable_cluster_logging              = false

  tags = local.tags
}
