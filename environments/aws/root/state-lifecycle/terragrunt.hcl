include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/aws/s3-lifecycle"
}

locals {
  environment = "root"
  aws_region  = "eu-west-1"
}

inputs = {
  bucket_name = "iac-foundation-tf-state"
}
