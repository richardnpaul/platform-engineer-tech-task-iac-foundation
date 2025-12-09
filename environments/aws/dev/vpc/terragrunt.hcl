# Shared VPC and ALB Stack
#
# Creates shared networking infrastructure for dev environment:
# - VPC with public and private subnets
# - NAT Gateway
# - Application Load Balancer with target groups for EKS clusters

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "dev"
  region      = "us-east-1"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Purpose     = "shared-networking"
    Project     = "platform-foundation"
  }
}

terraform {
  source = "../../../../modules/aws/vpc"
}

inputs = {
  vpc_name = "dev-shared-vpc"
  vpc_cidr = "10.0.0.0/16"

  # Public subnets for ALB and NAT Gateway (across 2 AZs for HA)
  public_subnets = {
    us-east-1a = {
      cidr = "10.0.1.0/24"
      az   = "us-east-1a"
      tags = {
        "kubernetes.io/role/elb" = "1"
      }
    }
    us-east-1b = {
      cidr = "10.0.2.0/24"
      az   = "us-east-1b"
      tags = {
        "kubernetes.io/role/elb" = "1"
      }
    }
  }

  # Private subnets for Fargate pods (across 2 AZs for HA)
  private_subnets = {
    us-east-1a = {
      cidr = "10.0.101.0/24"
      az   = "us-east-1a"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
      }
    }
    us-east-1b = {
      cidr = "10.0.102.0/24"
      az   = "us-east-1b"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
      }
    }
  }

  # Shared ALB for both EKS clusters
  create_shared_alb       = true
  alb_deletion_protection = false

  # Target groups for management and application clusters
  alb_target_groups = {
    mgmt = {
      name              = "dev-eks-mgmt-tg"
      port              = 80
      health_check_path = "/healthz"
      priority          = 100
      host_headers      = ["argocd.dev.example.com"]
      tags = {
        Cluster = "mgmt-cluster"
      }
    }
    apps = {
      name              = "dev-eks-apps-tg"
      port              = 80
      health_check_path = "/healthz"
      priority          = 200
      host_headers      = ["*.apps.dev.example.com"]
      tags = {
        Cluster = "apps-cluster"
      }
    }
  }

  tags = local.tags
}
