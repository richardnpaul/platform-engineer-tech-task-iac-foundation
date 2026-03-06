variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "eks_mgmt_cluster_name" {
  description = "Name of EKS management cluster"
  type        = string
}

variable "eks_apps_cluster_name" {
  description = "Name of EKS apps cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
