# Application EKS Cluster
#
# Hosts application workloads deployed via ArgoCD
# Uses shared VPC and ALB target group from vpc stack

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id                 = "vpc-mock123456"
    private_subnet_list    = ["subnet-mock1", "subnet-mock2"]
    alb_security_group_id  = "sg-mock123456"
    target_group_arns      = {
      mgmt = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock-mgmt/1234567890123456"
      apps = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock-apps/1234567890123456"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  skip_outputs = false
}

locals {
  environment = "dev"
  region      = "us-east-1"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Purpose     = "application-workloads"
    Cluster     = "apps-cluster"
    Project     = "platform-foundation"
  }
}

terraform {
  source = "../../../../modules/aws/eks"
}

inputs = {
  cluster_name       = "dev-apps-cluster"
  kubernetes_version = "1.31"

  # Use shared VPC
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_list

  # Connect to shared ALB
  alb_security_group_id = dependency.vpc.outputs.alb_security_group_id
  alb_target_group_arn  = dependency.vpc.outputs.target_group_arns["apps"]

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
