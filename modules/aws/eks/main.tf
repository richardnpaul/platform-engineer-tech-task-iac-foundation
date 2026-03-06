# EKS Cluster with Fargate (uses external VPC)
#
# Cost-optimized EKS design:
# - Uses external VPC for shared networking (~$48/month shared across clusters)
# - Fargate serverless compute (400 vCPU-hours FREE/month)
# - EKS control plane: $73/month per cluster
# - Optional ALB target group integration
#
# Total per cluster: $73/month + proportional share of networking

terraform {
  required_version = ">= 1.14,<2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0,<7.0"
    }
  }
}

# Locals to resolve VPC/subnet IDs from either direct input or data sources
locals {
  vpc_id               = var.vpc_id != null ? var.vpc_id : try(data.aws_vpc.selected[0].id, null)
  subnet_ids           = var.subnet_ids != null ? var.subnet_ids : try(data.aws_subnets.private[0].ids, null)
  alb_target_group_arn = var.alb_target_group_arn != null ? var.alb_target_group_arn : try(data.aws_lb_target_group.selected[0].arn, null)
  # Convert security_groups set to list before indexing
  alb_security_group_id = var.alb_security_group_id != null ? var.alb_security_group_id : try(tolist(data.aws_lb.selected[0].security_groups)[0], null)
}

# Security group for EKS cluster
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Security group for Fargate pods
resource "aws_security_group" "pods" {
  name        = "${var.cluster_name}-pods-sg"
  description = "Security group for Fargate pods"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-pods-sg"
  })
}

# Allow ALB to communicate with pods
# Uses for_each with static boolean to avoid issues with computed values
resource "aws_security_group_rule" "alb_to_pods" {
  for_each = var.enable_alb_integration ? toset(["enabled"]) : toset([])

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.pods.id
  source_security_group_id = var.alb_security_group_id
  description              = "Allow traffic from ALB"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Minimal logging to reduce costs
  enabled_cluster_log_types = var.enable_cluster_logging ? ["api", "audit"] : []

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = var.tags
}

# OIDC Provider for IRSA
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Fargate Profile for kube-system (CoreDNS)
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = local.subnet_ids

  selector {
    namespace = "kube-system"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.fargate_pod_execution
  ]
}

# Fargate Profiles for application namespaces
resource "aws_eks_fargate_profile" "app_namespaces" {
  for_each = toset(var.fargate_namespaces)

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-${each.value}"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = local.subnet_ids

  selector {
    namespace = each.value
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.fargate_pod_execution
  ]
}
