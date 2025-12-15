# Application EKS Cluster
#
# Hosts application workloads deployed via ArgoCD
# Uses shared VPC and ALB target group from vpc stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "dev"
  region      = "eu-west-1"
  cluster     = "apps-cluster"

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Purpose     = "application-workloads"
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

  # Lookup VPC by name (module will use data sources)
  vpc_name = "shared-vpc"

  # Subnet tags for lookup
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Environment" = local.environment
  }

  # ALB target group name for lookup
  alb_target_group_name = "apps-tg"
  alb_name              = "shared-alb"

  # Fargate namespaces (applications will be deployed here)
  fargate_namespaces = [
    "default",
    "production",
    "staging"
  ]

  # Enable AWS Load Balancer Controller for application ingress
  enable_aws_load_balancer_controller = true
  enable_cluster_logging              = false

  tags = local.tags
}
