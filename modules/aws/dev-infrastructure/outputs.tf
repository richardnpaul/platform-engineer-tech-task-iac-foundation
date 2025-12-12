output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_mgmt_cluster_endpoint" {
  description = "EKS management cluster endpoint"
  value       = module.eks_mgmt.cluster_endpoint
}

output "eks_apps_cluster_endpoint" {
  description = "EKS apps cluster endpoint"
  value       = module.eks_apps.cluster_endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.vpc.alb_dns_name
}
