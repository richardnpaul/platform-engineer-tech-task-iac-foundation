terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "bucket_name" {
  description = "Name of the existing S3 bucket"
  type        = string
}

# Add lifecycle policy to existing bucket for plan cleanup
resource "aws_s3_bucket_lifecycle_configuration" "plans_cleanup" {
  bucket = var.bucket_name

  rule {
    id     = "cleanup-terraform-plans"
    status = "Enabled"

    filter {
      prefix = "terraform-plans/"
    }

    expiration {
      days = 14
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

output "lifecycle_rule_id" {
  description = "ID of the lifecycle rule"
  value       = "cleanup-terraform-plans"
}

output "module_metadata" {
  description = "Module metadata"
  value = {
    bucket_name     = var.bucket_name
    prefix          = "terraform-plans/"
    expiration_days = 14
    rule_status     = "Enabled"
  }
}
