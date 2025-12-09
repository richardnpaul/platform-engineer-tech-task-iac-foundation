variable "environment" {
  description = "Logical environment name (e.g. root, dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region the module should target."
  type        = string
}

variable "tags" {
  description = "Common tags applied to created resources."
  type        = map(string)
  default     = {}
}
