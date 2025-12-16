# Environment Parameterization: Analysis

## Approach Comparison

### ❌ Original: Separate Environment Folders
```
environments/aws/
  dev/infrastructure/
  staging/infrastructure/
  prod/infrastructure/
```

**Problems:**
- Code duplication across environments
- Drift between environments (copy-paste errors)
- Must update 3 places for infrastructure changes
- Different Terragrunt files = different behavior risk

---

### ✅ Recommended: Single Stack + tfvars

```
environments/aws/infrastructure/
  terragrunt.hcl  # Single config
  dev.tfvars      # Dev values
  staging.tfvars  # Staging values
  prod.tfvars     # Prod values
```

**Benefits:**
- ✅ DRY: One Terragrunt config for all environments
- ✅ Consistency: Same code path guarantees identical behavior
- ✅ Easy to add environments: Just add new .tfvars file
- ✅ Clear diff: `diff dev.tfvars prod.tfvars` shows differences
- ✅ Type safety: Module validates all inputs
- ✅ Scalable: 10 environments = 10 tfvars files, not 10 folders

---

## How It Works in CI/CD

### GitHub Environments Feature

Create environments in GitHub: Settings → Environments → New environment

**dev environment:**
- No protection rules (auto-deploy)
- Variables: `AWS_REGION=eu-west-1`

**staging environment:**
- Required reviewers: DevOps team
- Variables: `AWS_REGION=eu-west-1`

**prod environment:**
- Required reviewers: 2+ approvers
- Variables: `AWS_REGION=eu-west-1`
- Secrets: `PROD_ACCOUNT_ID`, etc.

### Workflow Behavior

**On PR:**
```yaml
matrix:
  environment: ["dev"]  # Plan dev only
```

**On merge to main:**
```yaml
matrix:
  environment: ["dev", "staging", "prod"]
max-parallel: 1  # Sequential: dev → staging → prod
```

**Manual dispatch:**
```yaml
inputs:
  environment: "prod"  # Choose specific environment
```

---

## Knock-on Effects & Downsides

### ✅ Advantages

1. **State Separation Maintained**
   - Each environment still has separate state file
   - Terragrunt state key: `${project}/infrastructure-${environment}/terraform.tfstate`

2. **No Hardcoded Values**
   - Everything parameterized
   - Easy to template

3. **Easy Testing**
   - Test in dev first
   - Promote same config to staging/prod
   - No "it works in dev but not prod" surprises

4. **Cost Visibility**
   - Compare `dev.tfvars` vs `prod.tfvars`
   - See exactly what's different (NAT count, instance sizes, etc.)

5. **Compliance**
   - Prod environment has approval gates
   - Audit trail in GitHub

### ⚠️ Downsides (Minor)

1. **State Key Complexity**
   - Need to modify `root.hcl` to include environment in state key
   - Otherwise all environments share same state file (BAD!)

2. **Initial Setup**
   - Need to create GitHub environments
   - Set up approval rules

3. **Slightly More Complex Workflow**
   - Matrix strategy instead of simple steps
   - But much more powerful

4. **Can't Have Environment-Specific Logic**
   - If you need totally different infrastructure in prod
   - (e.g., prod has 10 extra services)
   - Then separate stacks make more sense
   - But for similar infrastructure, this is better

### 🔴 Critical: State Key Must Include Environment!

**Current `root.hcl`:**
```hcl
state_key = "${local.project_name}/${local.state_prefix}/terraform.tfstate"
```

**Must become:**
```hcl
state_key = "${local.project_name}/${get_env("TF_VAR_environment", "default")}/${local.state_prefix}/terraform.tfstate"
```

Otherwise all environments overwrite each other's state!

---

## Alternative: Workspace-Based (NOT Recommended)

Terraform workspaces seem appealing but are problematic:

```bash
terraform workspace select dev
terraform apply
```

**Why not:**
- ❌ Easy to apply to wrong workspace
- ❌ State stored in same backend (risk of corruption)
- ❌ Can't have different backends per environment
- ❌ Less visible than explicit tfvars files
- ❌ GitHub environment protection doesn't work

---

## Recommendation: Use Environment Parameterization

**When to use:**
- ✅ Multiple environments (dev/staging/prod)
- ✅ Environments are similar (same infrastructure, different sizes)
- ✅ Want to prevent drift
- ✅ Need approval workflows

**When NOT to use:**
- ❌ Environments are radically different
- ❌ Different teams own different environments
- ❌ Different AWS accounts with different access patterns
- ❌ Only 1 environment (just hardcode values)

For your case (dev/staging/prod with similar infrastructure), environment parameterization is the best approach.
