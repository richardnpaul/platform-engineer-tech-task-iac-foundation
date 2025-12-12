# Management EKS Cluster for ArgoCD
#
# Hosts ArgoCD for GitOps deployments to both clusters
# Uses shared VPC and ALB target group from vpc stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "dev"
  region      = "eu-west-1"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Purpose     = "argocd-management"
    Cluster     = "mgmt-cluster"
    Project     = "platform-foundation"
  }
}

terraform {
  source = "../../../../modules/aws/eks"
}

inputs = {
  cluster_name       = "dev-mgmt-cluster"
  kubernetes_version = "1.31"

  # Lookup VPC by name (module will use data sources)
  vpc_name = "dev-shared-vpc"

  # Subnet tags for lookup
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Environment" = "dev"
  }

  # ALB target group name for lookup
  alb_target_group_name = "dev-mgmt-tg"
  alb_name              = "dev-shared-alb"

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
