variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

# Option 1: Pass VPC/subnet IDs directly (original approach)
variable "vpc_id" {
  description = "VPC ID where the cluster will be created (optional if vpc_name is provided)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster and Fargate pods (optional if subnet tags provided)"
  type        = list(string)
  default     = null
}

# Option 2: Lookup by name/tags using data sources
variable "vpc_name" {
  description = "Name of VPC to lookup (alternative to vpc_id)"
  type        = string
  default     = null
}

variable "private_subnet_tags" {
  description = "Tags to filter private subnets (alternative to subnet_ids)"
  type        = map(string)
  default     = null
}

variable "enable_alb_integration" {
  description = "Whether to create security group rules for ALB integration"
  type        = bool
  default     = false
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB to allow traffic to pods (optional)"
  type        = string
  default     = null
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group to associate with this cluster (optional if alb_target_group_name provided)"
  type        = string
  default     = null
}

variable "alb_target_group_name" {
  description = "Name of ALB target group to lookup (alternative to alb_target_group_arn)"
  type        = string
  default     = null
}

variable "alb_name" {
  description = "Name of ALB to lookup security group (optional)"
  type        = string
  default     = null
}

variable "fargate_namespaces" {
  description = "List of Kubernetes namespaces to run on Fargate"
  type        = list(string)
  default     = ["default"]
}

variable "enable_cluster_logging" {
  description = "Enable EKS cluster logging (api, audit)"
  type        = bool
  default     = false
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable IAM role and policy for AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
