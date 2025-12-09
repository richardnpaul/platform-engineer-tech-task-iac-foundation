# Quick Start: CI/CD Setup

This guide walks through enabling CI/CD for infrastructure deployments.

## Prerequisites

- ✅ GitHub repository with code pushed
- ✅ AWS Organizations root account access
- ✅ GitHub repository admin access

## Step 1: Deploy Organizations Stack (Manual)

The Organizations stack creates AWS accounts and requires admin credentials, so it's deployed manually:

```bash
export TF_VAR_dev_email="dev-aws@yourcompany.com"

cd environments/aws/root/organizations
terragrunt init
terragrunt plan
terragrunt apply
```

**Save the output:** Note the dev account ID for later use.

## Step 2: Deploy GitHub OIDC Stack (Manual First Time)

This creates the IAM role for GitHub Actions:

```bash
cd ../deployment/github-oidc
terragrunt init
terragrunt plan
terragrunt apply
```

**Outputs:**
- `github_actions_role_arn`: Copy this ARN

## Step 3: Configure GitHub Repository Secrets

Go to `Settings` → `Secrets and variables` → `Actions` → `New repository secret`:

| Name | Value |
|------|-------|
| `DEV_ACCOUNT_EMAIL` | `dev-aws@yourcompany.com` |

## Step 4: Configure GitHub Environment

Go to `Settings` → `Environments` → `New environment`:

**Name:** `production`

**Protection rules:**
- ✅ Required reviewers
  - Add yourself and/or team members
- ⚠️ Optional: Wait timer (5 minutes)

Click **Save protection rules**.

## Step 5: Verify Workflow Syntax

```bash
# Install act for local testing (optional)
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test workflow syntax
act -l
```

Or just push and let GitHub validate it.

## Step 6: Test with a PR

### Create a test branch

```bash
git checkout -b test/cicd-setup
```

### Make a trivial change

```bash
echo "# CI/CD Test" >> docs/cicd-test.md
git add docs/cicd-test.md
git commit -m "test: verify CI/CD pipeline"
git push origin test/cicd-setup
```

### Create PR on GitHub

```bash
gh pr create --title "Test CI/CD Pipeline" --body "Testing automated Terraform plans"
```

### Expected Behavior

1. Workflow triggers automatically
2. Plans run for all stacks:
   - ✅ GitHub OIDC (no changes expected)
   - ✅ Dev VPC (no changes expected, or creates if first run)
   - ✅ Dev EKS Mgmt (no changes expected, or creates if first run)
   - ✅ Dev EKS Apps (no changes expected, or creates if first run)
3. Bot comments on PR with plan details
4. Review the plans in the PR comment

### If Plans Succeed

✅ CI/CD is working! You can close this test PR or merge it.

### If Plans Fail

❌ Check the workflow logs in `Actions` tab:

**Common issues:**
- Missing AWS permissions: Update `github-oidc` role policy
- Missing dependencies: Deploy VPC manually first
- Syntax errors: Run `terraform validate` locally

## Step 7: Deploy Infrastructure via CI/CD

### Option A: Deploy VPC First (Recommended)

If VPC doesn't exist yet, create a PR to deploy it:

```bash
git checkout -b feat/deploy-dev-vpc
# No code changes needed - just trigger CI/CD
git commit --allow-empty -m "feat: deploy dev VPC infrastructure"
git push origin feat/deploy-dev-vpc
gh pr create --title "Deploy Dev VPC" --body "Deploys shared VPC, NAT gateway, and ALB"
```

**Review plan** → **Merge PR** → **Approve in GitHub Environment** → **VPC deployed!**

### Option B: Deploy All at Once

If you want to deploy everything in one go:

```bash
git checkout -b feat/deploy-dev-environment
git commit --allow-empty -m "feat: deploy complete dev environment"
git push origin feat/deploy-dev-environment
gh pr create --title "Deploy Dev Environment" --body "Deploys VPC, EKS mgmt cluster, and EKS apps cluster"
```

**Review plans** → **Merge PR** → **Approve** → **All stacks deployed!**

## Step 8: Verify Deployment

### Check AWS Console

1. **VPC:** `us-east-1` region → VPC with name `dev-shared-vpc`
2. **ALB:** EC2 → Load Balancers → `dev-shared-alb`
3. **EKS:** EKS → Clusters → `dev-mgmt-cluster`, `dev-apps-cluster`

### Check via CLI

```bash
# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dev-shared-vpc" --region us-east-1

# ALB
aws elbv2 describe-load-balancers --region us-east-1 | jq '.LoadBalancers[] | select(.LoadBalancerName | contains("dev-shared"))'

# EKS Clusters
aws eks list-clusters --region us-east-1
aws eks describe-cluster --name dev-mgmt-cluster --region us-east-1
aws eks describe-cluster --name dev-apps-cluster --region us-east-1
```

### Check via Terraform

```bash
cd environments/aws/dev/vpc
terragrunt output

cd ../eks-mgmt
terragrunt output

cd ../eks-apps
terragrunt output
```

## Step 9: Configure kubectl

```bash
# Management cluster
aws eks update-kubeconfig --name dev-mgmt-cluster --region us-east-1

# Application cluster
aws eks update-kubeconfig --name dev-apps-cluster --region us-east-1 --alias apps

# Verify
kubectl get nodes
kubectl get nodes --context apps
```

## Step 10: Deploy Workloads

Follow the post-deployment steps in `docs/dev-deployment-guide.md`:

1. Install AWS Load Balancer Controller
2. Install ArgoCD
3. Configure DNS for ALB
4. Deploy first application

## Ongoing Workflow

### Making Infrastructure Changes

```bash
# 1. Create feature branch
git checkout -b feat/add-staging-namespace

# 2. Edit infrastructure
vim environments/aws/dev/eks-apps/terragrunt.hcl
# Add "staging" to fargate_namespaces

# 3. Commit and push
git add .
git commit -m "feat: add staging namespace to apps cluster"
git push origin feat/add-staging-namespace

# 4. Create PR
gh pr create --title "Add Staging Namespace" --body "Adds Fargate profile for staging namespace"

# 5. Review plan in PR comment

# 6. Merge PR

# 7. Approve deployment in GitHub Environments

# 8. Verify changes applied
kubectl get fargate-profile -n staging --cluster apps
```

### Monitoring Deployments

- **GitHub Actions:** Check `Actions` tab for workflow runs
- **AWS CloudTrail:** See API calls made by the OIDC role
- **Terraform State:** Stored in S3, versioned automatically

## Troubleshooting

### "Error: AccessDenied" during plan

**Solution:** Update IAM permissions in `github-oidc` stack:

```bash
# Edit permissions
vim modules/aws/github-oidc/main.tf

# Deploy updated permissions manually
cd environments/aws/root/deployment/github-oidc
terragrunt apply

# Re-run the PR workflow
gh workflow run terraform.yml
```

### "Error: DependencyNotReady"

**Solution:** Deploy dependencies first:

```bash
# Deploy VPC manually
cd environments/aws/dev/vpc
terragrunt apply

# Then re-run CI/CD
```

### Workflow doesn't trigger on PR

**Solution:** Check trigger paths in `.github/workflows/terraform.yml`:

```yaml
paths:
  - 'modules/**'
  - 'environments/**'
  - 'root.hcl'
  - '.github/workflows/terraform.yml'
```

If you edited a file outside these paths, the workflow won't trigger.

### "No plan artifacts found" during apply

**Solution:**
- Plans are only valid for the exact commit that generated them
- If you push new commits after plan, you need to re-plan
- Close and re-open the PR to trigger a new plan

## Security Checklist

- [x] OIDC role has permissions boundary
- [x] GitHub Environment requires approval
- [x] Repository secrets are encrypted
- [x] Plan artifacts auto-delete after 7 days
- [x] No AWS credentials stored in GitHub
- [ ] Enable branch protection on `main`
- [ ] Require status checks to pass before merging
- [ ] Require signed commits (optional)
- [ ] Enable audit logging for repository

## Next Steps

1. **Add more environments:** staging, production
2. **Implement drift detection:** scheduled workflow to check for manual changes
3. **Add cost estimation:** Infracost integration
4. **Set up monitoring:** Deploy Prometheus/Grafana via ArgoCD
5. **Configure backups:** Velero for EKS cluster backups
6. **Implement disaster recovery:** Document and test recovery procedures

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Cloud OIDC](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
