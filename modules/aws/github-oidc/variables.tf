variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "allow_legacy_pull_request" {
  description = "Allow authentication using the legacy pull_request subject (without environment)"
  type        = bool
  default     = false
}

variable "allowed_subjects" {
  description = "DEPRECATED: Use environment-based authentication instead. List of allowed GitHub OIDC subject patterns"
  type        = list(string)
  default     = []
}

variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "GitHubActionsDeploymentRole"
}

variable "session_duration" {
  description = "Maximum session duration in seconds (1-12 hours)"
  type        = number
  default     = 3600 # 1 hour

  validation {
    condition     = var.session_duration >= 3600 && var.session_duration <= 43200
    error_message = "Session duration must be between 3600 (1 hour) and 43200 (12 hours)"
  }
}

variable "target_account_ids" {
  description = "List of AWS account IDs that this role can deploy to"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for cross-account role assumption (shared secret)"
  type        = string
  sensitive   = true
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state storage"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
