# Dev Environment Configuration
# Applied via: terragrunt plan -var-file=dev.tfvars

# Required variables
vpc_cidr = "10.0.0.0/16"

eks_mgmt_cluster_name = "dev-mgmt-cluster"
eks_apps_cluster_name = "dev-apps-cluster"
kubernetes_version    = "1.31"

# Note: environment and region are set via TF_VAR_environment and TF_VAR_region
# in the CI/CD workflow or local environment
