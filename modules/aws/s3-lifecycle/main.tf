terraform {
  required_version = ">= 1.14,<2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0,<7.0"
    }
  }
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
