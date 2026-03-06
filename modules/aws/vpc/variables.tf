variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Map of public subnets with CIDR and AZ"
  type = map(object({
    cidr = string
    az   = string
    tags = optional(map(string), {})
  }))
}

variable "private_subnets" {
  description = "Map of private subnets with CIDR and AZ"
  type = map(object({
    cidr = string
    az   = string
    tags = optional(map(string), {})
  }))
}

variable "create_shared_alb" {
  description = "Whether to create a shared Application Load Balancer"
  type        = bool
  default     = false
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "alb_target_groups" {
  description = "Map of target groups for the shared ALB"
  type = map(object({
    name              = string
    port              = number
    health_check_path = string
    priority          = number
    host_headers      = list(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
