variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster and Fargate pods"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB to allow traffic to pods (optional)"
  type        = string
  default     = null
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group to associate with this cluster (optional)"
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
