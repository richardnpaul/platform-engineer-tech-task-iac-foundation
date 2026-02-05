# Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# OIDC Provider Outputs
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

# Fargate Outputs
output "fargate_profile_ids" {
  description = "Map of Fargate profile IDs"
  value = merge(
    { kube-system = aws_eks_fargate_profile.kube_system.id },
    { for k, v in aws_eks_fargate_profile.app_namespaces : k => v.id }
  )
}

output "fargate_pod_execution_role_arn" {
  description = "ARN of the Fargate pod execution role"
  value       = aws_iam_role.fargate.arn
}

output "pods_security_group_id" {
  description = "Security group ID for Fargate pods"
  value       = aws_security_group.pods.id
}

# AWS Load Balancer Controller Outputs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].name : null
}
