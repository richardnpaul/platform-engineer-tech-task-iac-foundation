# Module Interface Reference

Quick reference for using the VPC and EKS modules.

## VPC Module (`modules/aws/vpc`)

### Required Inputs

```hcl
vpc_name = "dev-shared-vpc"  # Name prefix for all resources

public_subnets = {
  us-east-1a = {
    cidr = "10.0.1.0/24"
    az   = "us-east-1a"
    tags = {}  # optional
  }
}

private_subnets = {
  us-east-1a = {
    cidr = "10.0.101.0/24"
    az   = "us-east-1a"
    tags = {}  # optional
  }
}
```

### Optional Inputs

```hcl
vpc_cidr                = "10.0.0.0/16"          # Default
create_shared_alb       = true                   # Create ALB, default: false
alb_deletion_protection = false                  # Enable deletion protection
tags                    = {}                     # Common tags

alb_target_groups = {
  cluster1 = {
    name              = "cluster1-tg"
    port              = 80
    health_check_path = "/healthz"
    priority          = 100                      # Listener rule priority (unique)
    host_headers      = ["app.example.com"]
    tags              = {}  # optional
  }
}
```

### Key Outputs

```hcl
vpc_id                 # VPC ID
vpc_cidr               # VPC CIDR block
public_subnet_ids      # Map: {az => subnet_id}
private_subnet_ids     # Map: {az => subnet_id}
public_subnet_list     # List of public subnet IDs
private_subnet_list    # List of private subnet IDs
nat_gateway_id         # NAT Gateway ID
nat_gateway_eip        # NAT Gateway public IP
alb_arn                # ALB ARN (null if not created)
alb_dns_name           # ALB DNS name
alb_zone_id            # ALB Route53 zone ID
alb_security_group_id  # ALB security group ID
target_group_arns      # Map: {cluster => tg_arn}
http_listener_arn      # HTTP listener ARN
```

### Example Usage

```hcl
terraform {
  source = "../../../../modules/aws/vpc"
}

inputs = {
  vpc_name          = "dev-vpc"
  create_shared_alb = true

  public_subnets = {
    us-east-1a = { cidr = "10.0.1.0/24", az = "us-east-1a", tags = {} }
    us-east-1b = { cidr = "10.0.2.0/24", az = "us-east-1b", tags = {} }
  }

  private_subnets = {
    us-east-1a = { cidr = "10.0.101.0/24", az = "us-east-1a", tags = {} }
    us-east-1b = { cidr = "10.0.102.0/24", az = "us-east-1b", tags = {} }
  }

  alb_target_groups = {
    mgmt = {
      name              = "dev-mgmt-tg"
      port              = 80
      health_check_path = "/healthz"
      priority          = 100
      host_headers      = ["argocd.dev.example.com"]
    }
  }
}
```

---

## EKS Module (`modules/aws/eks`)

### Required Inputs

```hcl
cluster_name = "dev-cluster"
vpc_id       = "vpc-xxxxx"           # From VPC module
subnet_ids   = ["subnet-a", "..."]   # Private subnets for Fargate
```

### Optional Inputs

```hcl
kubernetes_version                  = "1.31"                # Default
alb_security_group_id               = "sg-xxxxx"            # For ALB → pod traffic
alb_target_group_arn                = "arn:..."             # Target group ARN
fargate_namespaces                  = ["default"]           # Namespaces for Fargate
enable_cluster_logging              = false                 # API/audit logs
enable_aws_load_balancer_controller = false                 # Create IAM role for controller
tags                                = {}                    # Common tags
```

### Key Outputs

```hcl
cluster_id                             # Cluster name
cluster_arn                            # Cluster ARN
cluster_endpoint                       # API server endpoint
cluster_version                        # Kubernetes version
cluster_security_group_id              # Control plane security group
cluster_certificate_authority_data     # CA cert (sensitive)
oidc_provider_arn                      # OIDC provider ARN
oidc_provider_url                      # OIDC provider URL
fargate_profile_ids                    # Map: {namespace => profile_id}
fargate_pod_execution_role_arn         # Pod execution role ARN
pods_security_group_id                 # Fargate pods security group
aws_load_balancer_controller_role_arn  # IAM role ARN (if enabled)
aws_load_balancer_controller_role_name # IAM role name (if enabled)
```

### Example Usage

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "../../../../modules/aws/eks"
}

inputs = {
  cluster_name = "dev-mgmt-cluster"

  # Networking from VPC module
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_list

  # ALB integration
  alb_security_group_id = dependency.vpc.outputs.alb_security_group_id
  alb_target_group_arn  = dependency.vpc.outputs.target_group_arns["mgmt"]

  # Fargate configuration
  fargate_namespaces = ["default", "argocd"]

  # Optional features
  enable_aws_load_balancer_controller = true
  enable_cluster_logging              = false
}
```

---

## Terragrunt Dependency Pattern

When using these modules together, use Terragrunt dependencies:

```hcl
# eks-mgmt/terragrunt.hcl
dependency "vpc" {
  config_path = "../vpc"

  # Optional: mock outputs for planning without VPC deployed
  mock_outputs = {
    vpc_id                 = "vpc-mock"
    private_subnet_list    = ["subnet-mock-1", "subnet-mock-2"]
    alb_security_group_id  = "sg-mock"
    target_group_arns      = { mgmt = "arn:mock:targetgroup" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vpc_id                = dependency.vpc.outputs.vpc_id
  subnet_ids            = dependency.vpc.outputs.private_subnet_list
  alb_security_group_id = dependency.vpc.outputs.alb_security_group_id
  alb_target_group_arn  = dependency.vpc.outputs.target_group_arns["mgmt"]
}
```

---

## Common Patterns

### Multi-AZ VPC

```hcl
public_subnets = {
  us-east-1a = { cidr = "10.0.1.0/24", az = "us-east-1a", tags = { "kubernetes.io/role/elb" = "1" } }
  us-east-1b = { cidr = "10.0.2.0/24", az = "us-east-1b", tags = { "kubernetes.io/role/elb" = "1" } }
}

private_subnets = {
  us-east-1a = { cidr = "10.0.101.0/24", az = "us-east-1a", tags = { "kubernetes.io/role/internal-elb" = "1" } }
  us-east-1b = { cidr = "10.0.102.0/24", az = "us-east-1b", tags = { "kubernetes.io/role/internal-elb" = "1" } }
}
```

### Multiple Clusters with ALB

```hcl
alb_target_groups = {
  mgmt = {
    name              = "mgmt-tg"
    port              = 80
    health_check_path = "/healthz"
    priority          = 100
    host_headers      = ["argocd.example.com"]
  }
  apps = {
    name              = "apps-tg"
    port              = 80
    health_check_path = "/healthz"
    priority          = 200
    host_headers      = ["*.apps.example.com"]
  }
}
```

### Fargate Namespace Configuration

```hcl
# Management cluster
fargate_namespaces = ["default", "argocd"]

# Application cluster
fargate_namespaces = ["default", "production", "staging"]
```

---

## Tips

1. **Subnet sizing:** Use `/24` for each subnet (251 usable IPs)
   - Fargate reserves 1 IP per pod
   - Plan for ~200 pods per AZ max with `/24`

2. **Target group priorities:** Must be unique per listener
   - Use increments of 100: 100, 200, 300...

3. **Health check paths:** Ensure services expose this endpoint
   - Default: `/healthz`
   - Update in target group config if different

4. **Host headers:** Can use wildcards
   - `argocd.dev.example.com` - exact match
   - `*.apps.dev.example.com` - wildcard

5. **Fargate profiles:** Create before deploying pods
   - CoreDNS requires `kube-system` profile
   - Add namespace before deploying workloads

6. **IRSA setup:** Use OIDC provider outputs
   ```hcl
   assume_role_policy = jsonencode({
     Version = "2012-10-17"
     Statement = [{
       Effect = "Allow"
       Principal = {
         Federated = dependency.eks.outputs.oidc_provider_arn
       }
       Action = "sts:AssumeRoleWithWebIdentity"
       Condition = {
         StringEquals = {
           "${replace(dependency.eks.outputs.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:namespace:sa-name"
         }
       }
     }]
   })
   ```
