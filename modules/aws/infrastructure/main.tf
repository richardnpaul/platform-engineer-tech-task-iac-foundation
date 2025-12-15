# Dev Infrastructure - Merged Stack
#
# Single module that creates VPC + both EKS clusters
# No dependencies, no data sources, pure Terraform references

terraform {
  required_version = ">= 1.14"
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Use VPC module
module "vpc" {
  source = "../vpc"

  vpc_name = "${var.environment}-shared-vpc"
  vpc_cidr = var.vpc_cidr

  public_subnets = {
    "${var.region}a" = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 1)
      az   = "${var.region}a"
      tags = { "kubernetes.io/role/elb" = "1" }
    }
    "${var.region}b" = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 2)
      az   = "${var.region}b"
      tags = { "kubernetes.io/role/elb" = "1" }
    }
  }

  private_subnets = {
    "${var.region}a" = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 11)
      az   = "${var.region}a"
      tags = { "kubernetes.io/role/internal-elb" = "1" }
    }
    "${var.region}b" = {
      cidr = cidrsubnet(var.vpc_cidr, 8, 12)
      az   = "${var.region}b"
      tags = { "kubernetes.io/role/internal-elb" = "1" }
    }
  }

  # Enable shared ALB with target groups for both clusters
  create_shared_alb       = true
  alb_deletion_protection = false

  alb_target_groups = {
    mgmt = {
      name              = "${var.environment}-mgmt-tg"
      port              = 80
      health_check_path = "/healthz"
      priority          = 100
      host_headers      = ["argocd.${var.environment}.example.com"]
    }
    apps = {
      name              = "${var.environment}-apps-tg"
      port              = 80
      health_check_path = "/healthz"
      priority          = 200
      host_headers      = ["*.${var.environment}.example.com"]
    }
  }

  tags = var.tags
}

# EKS Management Cluster - Direct reference to VPC module outputs
module "eks_mgmt" {
  source = "../eks"

  cluster_name       = var.eks_mgmt_cluster_name
  kubernetes_version = var.kubernetes_version

  # Direct Terraform references - no dependencies, no data sources!
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_list

  enable_alb_integration = true
  alb_security_group_id  = module.vpc.alb_security_group_id
  alb_target_group_arn   = module.vpc.target_group_arns["mgmt"]

  fargate_namespaces                  = ["default", "argocd"]
  enable_aws_load_balancer_controller = true
  enable_cluster_logging              = false

  tags = merge(var.tags, {
    Purpose = "argocd-management"
    Cluster = "mgmt-cluster"
  })
}

# EKS Apps Cluster - Direct reference to VPC module outputs
module "eks_apps" {
  source = "../eks"

  cluster_name       = var.eks_apps_cluster_name
  kubernetes_version = var.kubernetes_version

  # Direct Terraform references - no dependencies, no data sources!
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_list

  enable_alb_integration = true
  alb_security_group_id  = module.vpc.alb_security_group_id
  alb_target_group_arn   = module.vpc.target_group_arns["apps"]

  fargate_namespaces                  = ["default", "production", "staging"]
  enable_aws_load_balancer_controller = true
  enable_cluster_logging              = false

  tags = merge(var.tags, {
    Purpose = "application-workloads"
    Cluster = "apps-cluster"
  })
}
