variable "log_archive_email" {
  description = "Email address for the Log Archive account"
  type        = string
}

variable "audit_email" {
  description = "Email address for the Security Audit account"
  type        = string
}

variable "deployment_email" {
  description = "Email address for the Deployment/CI-CD account"
  type        = string
}

variable "dev_email" {
  description = "Email address for the Development account"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}
