locals {
  project_name   = "iac-foundation"
  cloud_provider = lower(get_env("TG_CLOUD", "aws"))
  state_prefix   = path_relative_to_include()
  default_region = "eu-west-1"

  backend_definitions = {
    aws = {
      backend = "s3"
      config = merge(
        {
          bucket       = get_env("TG_STATE_BUCKET", "iac-foundation-tf-state")
          region       = get_env("TG_STATE_REGION", local.default_region)
          encrypt      = true
          use_lockfile = true
        },
        # Use terraform-bootstrap profile locally, omit profile in CI (uses OIDC credentials)
        get_env("CI", "") == "" ? { profile = get_env("AWS_PROFILE", "terraform-bootstrap") } : {}
      )
    }
    gcp = {
      backend = "gcs"
      config = {
        bucket   = get_env("TG_GCS_BUCKET", "iac-foundation-tf-state-gcp")
        prefix   = ""
        project  = get_env("GOOGLE_PROJECT", "")
        location = get_env("GOOGLE_LOCATION", "EU")
      }
    }
    azure = {
      backend = "azurerm"
      config = {
        resource_group_name  = get_env("TG_AZURE_RG", "iac-tfstate-rg")
        storage_account_name = get_env("TG_AZURE_STORAGE", "iacstate0001")
        container_name       = get_env("TG_AZURE_CONTAINER", "tfstate")
        key                  = ""
        subscription_id      = get_env("ARM_SUBSCRIPTION_ID", "")
        tenant_id            = get_env("ARM_TENANT_ID", "")
      }
    }
  }

  selected_backend = try(local.backend_definitions[local.cloud_provider], local.backend_definitions.aws)
  state_key        = "${local.project_name}/${local.state_prefix}/terraform.tfstate"

  backend_key_attribute = local.selected_backend.backend == "gcs" ? "prefix" : "key"

  backend_config_with_key = merge(
    local.selected_backend.config,
    local.backend_key_attribute == "prefix"
      ? { prefix = local.state_key }
      : { key = local.state_key }
  )
}

remote_state {
  backend = local.selected_backend.backend
  config  = local.backend_config_with_key
}

terraform {
  before_hook "bootstrap_state" {
    commands = ["init"]
    execute = [
      "bash",
      "${get_repo_root()}/scripts/foundation-bootstrap.sh",
      local.cloud_provider,
      local.state_key,
      try(local.selected_backend.config.bucket, ""),
      try(local.selected_backend.config.region, ""),
      try(local.selected_backend.config.profile, "")
    ]
  }
}

inputs = {
  project_name   = local.project_name
  cloud_provider = local.cloud_provider
}
