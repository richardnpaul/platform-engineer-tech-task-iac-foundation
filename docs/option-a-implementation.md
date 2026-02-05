# Option A Implementation Summary

## What Was Built

Implemented **Option A: Shared ALB in VPC module** with the following architecture:

### Infrastructure Components

1. **VPC Module** (`modules/aws/vpc/`)
   - Reusable VPC with public/private subnets
   - Single NAT Gateway for cost optimization
   - Shared Application Load Balancer
   - Multiple target groups (one per cluster)
   - Security groups for ALB → pod communication

2. **EKS Module** (`modules/aws/eks/`)
   - Accepts external VPC/networking parameters
   - Fargate-only compute (no EC2 nodes)
   - OIDC provider for IRSA
   - Optional AWS Load Balancer Controller IAM role
   - Configurable Fargate profiles per namespace

3. **Dev Environment Stacks** (`environments/aws/dev/`)
   - `vpc/`: Shared networking with 2 target groups
   - `eks-mgmt/`: Management cluster for ArgoCD
   - `eks-apps/`: Application workload cluster

4. **Organizations Update**
   - Added Development account to Workloads OU

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                              │
│                                                 │
│  ┌───────────────┐          ┌───────────────┐   │
│  │ Public Subnet │          │ Public Subnet │   │
│  │  eu-west-1a   │          │  eu-west-1b   │   │
│  │ 10.0.1.0/24   │          │ 10.0.2.0/24   │   │
│  └───────┬───────┘          └───────┬───────┘   │
│          │                          │           │
│          └──────────┬───────────────┘           │
│                     │                           │
│            ┌────────▼────────┐                  │
│            │  Shared ALB     │  ◄── Internet    │
│            │  (HTTP:80)      │                  │
│            └────────┬────────┘                  │
│                     │                           │
│         ┌───────────┴──────────┐                │
│         │                      │                │
│    ┌────▼─────┐         ┌──────▼───┐            │
│    │ Target   │         │ Target   │            │
│    │ Group    │         │ Group    │            │
│    │ (mgmt)   │         │ (apps)   │            │
│    └────┬─────┘         └──────┬───┘            │
│         │                      │                │
│  ┌──────▼──────────┐    ┌──────▼──────────┐     │
│  │ Private Subnet  │    │ Private Subnet  │     │
│  │  eu-west-1a     │    │  eu-west-1b     │     │
│  │ 10.0.101.0/24   │    │ 10.0.102.0/24   │     │
│  └─────────────────┘    └─────────────────┘     │
│         │                      │                │
│    ┌────▼─────┐         ┌──────▼───┐            │
│    │ Fargate  │         │ Fargate  │            │
│    │ Pods     │         │ Pods     │            │
│    │ (mgmt)   │         │ (apps)   │            │
│    └──────────┘         └──────────┘            │
│                                                 │
│    NAT Gateway ──────► Internet Gateway         │
└─────────────────────────────────────────────────┘
```

## Cost Breakdown

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| NAT Gateway | $32 | Single gateway shared |
| Shared ALB | $16 | One ALB for both clusters |
| EKS Control Plane (mgmt) | $73 | Management cluster |
| EKS Control Plane (apps) | $73 | Application cluster |
| Fargate compute | $0* | 400 vCPU-hours free tier |
| **Total** | **~$194/month** | *Beyond free tier: ~$0.04/vCPU-hour |

## Key Features

✅ **Cost-optimized:** Single NAT ($32) + single ALB ($16) shared across clusters
✅ **Serverless compute:** Fargate eliminates node management
✅ **IRSA-ready:** OIDC providers configured for service account roles
✅ **ALB controller:** IAM roles pre-configured for ingress automation
✅ **Multi-namespace:** Fargate profiles for argocd, default, production, staging
✅ **Secure networking:** Security groups control ALB → pod traffic
✅ **HA design:** Resources across 2 availability zones

## Routing Configuration

The shared ALB uses **host-based routing** to direct traffic:

- `argocd.dev.example.com` → Management cluster target group
- `*.apps.dev.example.com` → Application cluster target group

Each target group contains Fargate pod IPs (type: `ip`) and can be managed either:
1. Manually via AWS CLI (`aws elbv2 register-targets`)
2. Automatically via AWS Load Balancer Controller (recommended)

## Files Created

```
modules/aws/vpc/
├── main.tf          # VPC, subnets, NAT, ALB, target groups
├── variables.tf     # Input variables
└── outputs.tf       # VPC ID, subnet IDs, ALB DNS, TG ARNs

modules/aws/eks/
├── main.tf          # EKS cluster, Fargate, IRSA, IAM
├── variables.tf     # Cluster config, networking inputs
└── outputs.tf       # Cluster endpoint, OIDC, IAM roles

environments/aws/dev/vpc/
└── terragrunt.hcl   # VPC stack: 10.0.0.0/16, 2 AZs, ALB + TGs

environments/aws/dev/eks-mgmt/
└── terragrunt.hcl   # Management cluster (ArgoCD)

environments/aws/dev/eks-apps/
└── terragrunt.hcl   # Application cluster

modules/aws/organizations/
├── main.tf          # Added dev account resource
├── variables.tf     # Added dev_email variable
└── outputs.tf       # Added dev account outputs

docs/
└── dev-deployment-guide.md  # Step-by-step deployment instructions
```

## Deployment Order

1. **Organizations:** Create dev account in Workloads OU
2. **VPC:** Deploy shared networking infrastructure
3. **EKS Management:** Deploy cluster for ArgoCD
4. **EKS Applications:** Deploy cluster for workloads
5. **Post-deployment:** Install ALB controller, ArgoCD

## Design Decisions

**Why Option A (shared ALB) over B/C?**
- **Cost:** Single ALB ($16) vs. one per cluster ($32 total)
- **Simplicity:** VPC module owns all networking
- **Flexibility:** Easy to add more clusters/target groups
- **Security:** ALB in public subnets, pods in private subnets

**Why Fargate over EC2 nodes?**
- No node management/patching
- 400 vCPU-hours free tier (~2 small pods 24/7)
- Pay-per-pod pricing aligns with dev workload patterns
- No wasted capacity from oversized nodes

**Why two clusters vs. one?**
- **Isolation:** ArgoCD compromised ≠ apps compromised
- **Stability:** ArgoCD upgrades don't affect workloads
- **RBAC:** Simplified permissions (devs access apps, not ArgoCD)
- **Cost:** Only $73 more, worth it for production readiness

## Next Steps

1. **Deploy infrastructure** (see `docs/dev-deployment-guide.md`)
2. **Install AWS Load Balancer Controller** on one cluster
3. **Install ArgoCD** on management cluster
4. **Configure DNS** for `argocd.dev.example.com` → ALB
5. **Deploy first application** via ArgoCD to apps cluster
6. **Add staging/prod accounts** following same pattern

## Trade-offs

**Advantages:**
- Lowest cost for multi-cluster setup
- Clean separation of concerns (VPC ← EKS)
- Reusable modules for other environments
- Single ALB simplifies DNS/certificate management

**Disadvantages:**
- Shared ALB is single point of failure (mitigated by multi-AZ)
- Manual target registration required if ALB controller not installed
- Host-based routing requires unique DNS names per cluster
- NAT Gateway cost unavoidable for private subnet internet access

## Security Considerations

- ✅ Pods run in private subnets (no direct internet access)
- ✅ NAT Gateway for egress traffic
- ✅ Security groups control ALB → pod communication
- ✅ IRSA for pod-level IAM permissions (no instance profiles)
- ⚠️ ALB is internet-facing (use WAF/Shield for production)
- ⚠️ No network policies configured (add Calico/Cilium for pod-to-pod security)

## Validation

To validate the setup works:

```bash
# 1. Plan all stacks
cd environments/aws/dev/vpc && terragrunt plan
cd ../eks-mgmt && terragrunt plan
cd ../eks-apps && terragrunt plan

# 2. Check dependencies resolve
terragrunt graph-dependencies

# 3. Verify module syntax
terraform -chdir=modules/aws/vpc validate
terraform -chdir=modules/aws/eks validate
```

All stacks should plan successfully with dependency outputs resolving correctly.
