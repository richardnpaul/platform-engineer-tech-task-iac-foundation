# Platform Engineering IaC Foundation

Production-ready Terraform + Terragrunt infrastructure for multi-account AWS environments with cost-optimized EKS clusters, shared networking, and GitHub Actions CI/CD.

## What's Included

✅ **AWS Organizations** - Multi-account structure (Security, Infrastructure, Workloads OUs)
✅ **GitHub OIDC** - Secure CI/CD authentication (no static credentials)
✅ **Shared VPC** - Cost-optimized networking with single NAT Gateway ($32/month)
✅ **Shared ALB** - Application Load Balancer with multiple target groups ($16/month)
✅ **EKS Clusters** - Fargate-based serverless Kubernetes (2 clusters: mgmt + apps, $146/month)
✅ **CI/CD Pipeline** - Automated plan/apply via GitHub Actions
✅ **IRSA Support** - IAM Roles for Service Accounts pre-configured

**Total dev environment cost: ~$194/month**

## Quick Start

### Prerequisites

- Terraform ≥ 1.5
- Terragrunt ≥ 0.52
- AWS CLI with root account access
- GitHub repository admin access

### 1. Deploy Foundation (Manual)

```bash
# Set environment
export TG_CLOUD=aws
export TF_VAR_dev_email="dev-aws@yourcompany.com"

# Deploy Organizations
cd environments/aws/root/organizations
terragrunt apply

# Deploy GitHub OIDC
cd ../deployment/github-oidc
terragrunt apply
```

### 2. Configure CI/CD

See [docs/cicd-quickstart.md](docs/cicd-quickstart.md) for detailed setup.

**Summary:**
1. Add `DEV_ACCOUNT_EMAIL` secret to GitHub repository
2. Create `production` environment with required reviewers
3. Create PR to deploy infrastructure
4. Review plans, merge, approve deployment

### 3. Deploy Dev Environment (via CI/CD or Manual)

**Option A: Via GitHub Actions (Recommended)**
```bash
git checkout -b feat/deploy-dev-infrastructure
git commit --allow-empty -m "feat: deploy dev VPC and EKS clusters"
git push origin feat/deploy-dev-infrastructure
gh pr create --title "Deploy Dev Environment"
# Review plan → Merge → Approve → Deployed!
```

**Option B: Manual Deployment**
```bash
# VPC
cd environments/aws/dev/vpc
terragrunt apply

# EKS Management Cluster
cd ../eks-mgmt
terragrunt apply

# EKS Apps Cluster
cd ../eks-apps
terragrunt apply
```

### 4. Post-Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig --name dev-mgmt-cluster --region us-east-1

# Install AWS Load Balancer Controller
# (See docs/dev-deployment-guide.md for detailed steps)

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/cicd-quickstart.md](docs/cicd-quickstart.md) | CI/CD setup walkthrough |
| [docs/cicd-setup.md](docs/cicd-setup.md) | Detailed CI/CD documentation |
| [docs/dev-deployment-guide.md](docs/dev-deployment-guide.md) | Dev environment deployment guide |
| [docs/option-a-implementation.md](docs/option-a-implementation.md) | Architecture decisions and design |
| [docs/module-reference.md](docs/module-reference.md) | Module interface reference |
| [docs/github-oidc-setup.md](docs/github-oidc-setup.md) | GitHub OIDC integration guide |

## Architecture

### Multi-Account Structure

```
AWS Organizations (Root: 793421532223)
├── Security OU
│   ├── Log Archive Account
│   └── Security Audit Account
├── Infrastructure OU
│   └── Deployment Account (GitHub Actions)
└── Workloads OU
    └── Development Account (EKS clusters)
```

### Dev Environment Architecture

```
Dev VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── Shared ALB
│   └── NAT Gateway
└── Private Subnets (2 AZs)
    ├── EKS Management Cluster (Fargate)
    │   ├── ArgoCD namespace
    │   └── Connected to ALB target group (mgmt)
    └── EKS Apps Cluster (Fargate)
        ├── Production namespace
        ├── Staging namespace
        └── Connected to ALB target group (apps)
```

**ALB Routing:**
- `argocd.dev.example.com` → Management cluster
- `*.apps.dev.example.com` → Apps cluster

## Layout

```
.
├── root.hcl                     # Terragrunt root with multi-cloud state + bootstrapper
├── environments/
│   └── aws/
│       ├── root/
│       │   ├── organizations/   # AWS Organizations structure
│       │   └── deployment/
│       │       └── github-oidc/ # GitHub Actions OIDC role
│       └── dev/
│           ├── vpc/             # Shared VPC, NAT, ALB
│           ├── eks-mgmt/        # Management cluster (ArgoCD)
│           └── eks-apps/        # Application cluster
├── modules/
│   └── aws/
│       ├── organizations/       # Multi-account setup
│       ├── github-oidc/         # OIDC authentication
│       ├── vpc/                 # VPC with ALB and target groups
│       └── eks/                 # Fargate-based EKS cluster
├── scripts/
│   ├── bootstrap-state.sh       # S3/DynamoDB state backend setup
│   └── foundation-bootstrap.sh  # Helper scripts
├── docs/                        # Comprehensive documentation
└── .github/workflows/
    └── terraform.yml            # CI/CD pipeline
```

## Modules

### VPC Module (`modules/aws/vpc`)

Creates shared networking infrastructure:
- VPC with public/private subnets across multiple AZs
- Single NAT Gateway for cost optimization
- Shared Application Load Balancer
- Multiple target groups for cluster routing
- Security groups for ALB → pod communication

**Cost:** ~$48/month (NAT $32 + ALB $16)

### EKS Module (`modules/aws/eks`)

Fargate-based Kubernetes clusters:
- Serverless compute (no EC2 nodes)
- OIDC provider for IRSA
- Configurable Fargate profiles per namespace
- AWS Load Balancer Controller IAM role
- Integration with external VPC

**Cost:** $73/month per cluster

### GitHub OIDC Module (`modules/aws/github-oidc`)

Secure CI/CD authentication:
- IAM role for GitHub Actions
- Permissions boundary for defense-in-depth
- Trust policy for repository access
- Read-only boundary policy access

### Organizations Module (`modules/aws/organizations`)

Multi-account AWS structure:
- Organizational Units (Security, Infrastructure, Workloads)
- Account creation with lifecycle protection
- Standardized tagging and naming

## Remote State Strategy

- Select the cloud by exporting `TG_CLOUD` (`aws`, `gcp`, `azure`). Defaults to AWS.
- State configuration lives in `root.hcl` as a provider map. Each entry declares backend-specific attributes.
- State keys follow `${project_name}/${path_relative_to_include()}/terraform.tfstate`, so every stack gets an isolated object.
- `terraform.before_hook` invokes `scripts/bootstrap-state.sh` during `terragrunt init` to lazily create the state backend. Currently implemented for AWS (S3 bucket + DynamoDB table). The hook is a no-op for other clouds until their bootstrappers are added.

### AWS Defaults

| Variable | Default | Purpose |
| --- | --- | --- |
| `TG_STATE_BUCKET` | `iac-foundation-tf-state` | S3 bucket for terraform state |
| `TG_STATE_LOCK_TABLE` | `iac-foundation-tf-locks` | DynamoDB table for locking |
| `TG_STATE_REGION` | `eu-west-1` | Region for bucket/table |

Override values via env vars or by editing `root.hcl`.

## CI/CD Workflow

### Pull Request Flow

1. **Create branch** and make infrastructure changes
2. **Push to GitHub** → Workflow triggers automatically
3. **Plans generated** for all affected stacks
4. **Bot comments** on PR with plan details
5. **Review plans** → Approve PR
6. **Merge PR** → Apply job starts
7. **Manual approval** required in GitHub Environment
8. **Infrastructure deployed** in sequence

### Deployment Order

1. Organizations (manual, requires admin credentials)
2. GitHub OIDC (automated via CI/CD)
3. Dev VPC (automated via CI/CD)
4. Dev EKS Management (automated via CI/CD)
5. Dev EKS Apps (automated via CI/CD)

### Security Features

✅ No AWS credentials in GitHub (OIDC authentication)
✅ Permissions boundary restricts role capabilities
✅ Manual approval required for all applies
✅ All changes tracked in Git history
✅ Plan artifacts auto-deleted after 7 days

## Cost Breakdown

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| NAT Gateway | $32 | Single gateway shared across clusters |
| Application Load Balancer | $16 | Shared ALB with multiple target groups |
| EKS Control Plane (mgmt) | $73 | Management cluster for ArgoCD |
| EKS Control Plane (apps) | $73 | Application workload cluster |
| Fargate compute | $0* | 400 vCPU-hours FREE/month |
| **Total Dev Environment** | **~$194/month** | *Beyond free tier: ~$0.04/vCPU-hour |

**Cost optimization strategies:**
- Single NAT Gateway instead of per-AZ ($32 vs $96/month)
- Shared ALB instead of per-cluster ($16 vs $32/month)
- Fargate serverless compute (no idle nodes)
- No cluster logging by default
- Delete unused clusters when not needed

## Extending to Other Clouds

The foundation is cloud-agnostic and can be extended to GCP/Azure:

- Populate `modules/gcp` or `modules/azure` with landing zone modules
- Create matching `environments/<cloud>/.../terragrunt.hcl` files that include `root.hcl`
- Implement provider-specific bootstrap logic in `scripts/bootstrap-state.sh`
- Update `backend_definitions` map in `root.hcl` with GCS/Azure Storage configs
- Set `TG_CLOUD=gcp` or `TG_CLOUD=azure`

## Next Steps

### Immediate
1. ✅ Deploy Organizations and GitHub OIDC (manual)
2. ✅ Configure GitHub secrets and environments
3. ✅ Deploy dev VPC via CI/CD
4. ✅ Deploy EKS clusters via CI/CD
5. ⏳ Install AWS Load Balancer Controller
6. ⏳ Install ArgoCD on management cluster
7. ⏳ Configure DNS for ALB

### Short-term
- Add staging and production accounts
- Implement Prometheus/Grafana monitoring
- Configure External Secrets Operator
- Set up Velero for cluster backups
- Add network policies for pod security

### Long-term
- Multi-region EKS clusters
- Cross-cluster service mesh
- Automated disaster recovery
- Cost anomaly detection
- Compliance automation (CIS, SOC2)

## Troubleshooting

### Plan fails with "AccessDenied"

**Cause:** GitHub OIDC role lacks permissions.

**Solution:**
```bash
# Update role permissions
vim modules/aws/github-oidc/main.tf
cd environments/aws/root/deployment/github-oidc
terragrunt apply
```

### "DependencyNotReady" error

**Cause:** VPC hasn't been deployed yet.

**Solution:**
```bash
cd environments/aws/dev/vpc
terragrunt apply
```

### Fargate pods not starting

**Cause:** No Fargate profile for namespace.

**Solution:**
```bash
# Add namespace to fargate_namespaces input
vim environments/aws/dev/eks-mgmt/terragrunt.hcl
terragrunt apply
```

## Contributing

1. Create a feature branch
2. Make changes
3. Run `terraform validate` locally
4. Create PR (plans will run automatically)
5. Review plans in PR comment
6. Merge after approval
7. Approve deployment in GitHub Environment

## License

[LICENSE](LICENSE)

## Notes

- `scripts/bootstrap-state.sh` must be executable (`chmod +x scripts/bootstrap-state.sh`).
- The script is intentionally idempotent and safe to run repeatedly.
- Keep credentials out of the repo; leverage environment variables, AWS profiles, or secret stores managed by your automation pipeline.
