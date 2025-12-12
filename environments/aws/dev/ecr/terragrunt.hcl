include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/aws/ecr"
}

locals {
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Purpose     = "application-images"
    Project     = "platform-foundation"
  }
}

inputs = {
  repository_name      = "dev-app-repo"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  tags                 = local.tags
}
