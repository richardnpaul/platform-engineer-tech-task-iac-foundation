# Production Environment Configuration
# Applied via: terragrunt plan -var-file=prod.tfvars

# Required variables
vpc_cidr = "10.2.0.0/16"

eks_mgmt_cluster_name = "prod-mgmt-cluster"
eks_apps_cluster_name = "prod-apps-cluster"
# kubernetes_version    = "1.34"

# Note: environment and region are set via TF_VAR_environment and TF_VAR_region
# in the CI/CD workflow or local environment
