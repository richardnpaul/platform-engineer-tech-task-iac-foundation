# GitHub OIDC Authentication Setup

This document describes the GitHub OIDC authentication setup for automated deployments.

## Overview

The infrastructure uses OpenID Connect (OIDC) to authenticate GitHub Actions to AWS, eliminating the need for long-lived access keys. This provides:

- **Better Security**: Short-lived tokens instead of static credentials
- **Fine-grained Access**: Scoped to specific repositories and branches
- **Audit Trail**: Clear attribution in CloudTrail logs
- **Zero Secrets Management**: No credentials to rotate

## Architecture

```
GitHub Actions Workflow
    ↓ (OIDC Token)
AWS IAM OIDC Provider (token.actions.githubusercontent.com)
    ↓ (AssumeRoleWithWebIdentity)
GitHubActionsDeploymentRole (Management Account)
    ↓ (AssumeRole with ExternalId)
Target Account Roles (Deployment, Log Archive, Audit)
```

## Components

### 1. OIDC Provider
- **ARN**: `arn:aws:iam::793421532223:oidc-provider/token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Location**: Management account (793421532223)

### 2. GitHubActionsDeploymentRole
- **ARN**: `arn:aws:iam::793421532223:role/GitHubActionsDeploymentRole`
- **Session Duration**: 4 hours
- **Permissions Boundary**: `GitHubActionsPermissionsBoundary`

#### Trust Policy Conditions
```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:richardnpaul/platform-engineer-tech-task-iac-foundation:ref:refs/heads/main",
      "repo:richardnpaul/platform-engineer-tech-task-iac-foundation:pull_request"
    ]
  }
}
```

#### Permissions
- **Allowed**: Assume roles in target accounts matching `DeploymentTarget-*`
- **Denied**:
  - Creating access keys
  - Modifying permissions boundaries
  - Leaving organization
  - Closing accounts

### 3. Permissions Boundary
Prevents privilege escalation by:
- Restricting cross-account role assumption to specific patterns
- Denying modification of its own boundary
- Blocking dangerous actions (user creation, account closure)

## Using in GitHub Actions

### Workflow Pattern

The recommended workflow pattern uses plan artifacts to ensure the exact plan reviewed in a PR is applied:

1. **Plan Job** (PR trigger): Generate plan, upload as artifact, comment on PR
2. **Apply Job** (main push): Download artifact, apply exact plan

### Complete Workflow Example

```yaml
name: Deploy Infrastructure

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  id-token: write       # Required for OIDC
  contents: read        # Required to checkout
  pull-requests: write  # Required for PR comments

env:
  AWS_REGION: eu-west-1
  TERRAGRUNT_VERSION: 0.94.0
  TERRAFORM_VERSION: 1.14.1
  PLAN_ARTIFACT_NAME: tfplan-${{ github.event.pull_request.number || github.run_number }}-${{ github.sha }}

jobs:
  terraform-plan:
    runs-on: ubuntu-24.04
    if: github.event_name == 'pull_request'

    steps:
      - uses: actions/checkout@v6

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: arn:aws:iam::793421532223:role/GitHubActionsDeploymentRole
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: github-actions-${{ github.run_id }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
          terraform_wrapper: false

      - name: Setup Terragrunt
        run: |
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${{ env.TERRAGRUNT_VERSION }}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Terragrunt Plan
        working-directory: environments/aws/root/organizations
        run: |
          terragrunt plan -out=tfplan.binary 2>&1 | tee plan.txt
          terragrunt show -no-color tfplan.binary > tfplan.txt

      - name: Upload plan artifacts
        uses: actions/upload-artifact@v5
        if: (success() || failure()) && !cancelled()
        with:
          name: ${{ env.PLAN_ARTIFACT_NAME }}
          path: |
            environments/aws/root/organizations/tfplan.binary
            environments/aws/root/organizations/tfplan.txt
          retention-days: 7

      - name: Comment PR with plan
        uses: actions/github-script@v8
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('environments/aws/root/organizations/tfplan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### Terraform Plan\n\n<details><summary>Show Plan</summary>\n\n\`\`\`hcl\n${plan}\n\`\`\`\n\n</details>`
            });

  terraform-apply:
    runs-on: ubuntu-24.04
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production  # Requires manual approval

    steps:
      - uses: actions/checkout@v6

      - name: Download plan artifacts
        uses: actions/download-artifact@v6
        with:
          name: ${{ env.PLAN_ARTIFACT_NAME }}
          path: .

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: arn:aws:iam::793421532223:role/GitHubActionsDeploymentRole
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: github-actions-${{ github.run_id }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
          terraform_wrapper: false

      - name: Setup Terragrunt
        run: |
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${{ env.TERRAGRUNT_VERSION }}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Terragrunt Apply
        working-directory: environments/aws/root/organizations
        run: terragrunt apply tfplan.binary
```

### Key Security Features

1. **Plan Artifacts**: Binary plan files ensure no drift between plan and apply
2. **7-Day Retention**: Plans auto-delete after 7 days, or immediately after successful apply
3. **Environment Protection**: `production` environment requires manual approval
4. **Cancellable**: Avoids `if: always()` anti-pattern for proper cancellation support

### Cross-Account Deployment

To deploy to other accounts (e.g., deployment account), use the `role-chaining` parameter:

```yaml
- name: Configure AWS Credentials for Deployment Account
  uses: aws-actions/configure-aws-credentials@v5
  with:
    role-to-assume: arn:aws:iam::515048895906:role/DeploymentTarget-Terraform
    aws-region: eu-west-1
    role-chaining: true
    role-external-id: github-actions-deployment-2025
    role-session-name: deployment-${{ github.run_id }}

- name: Deploy to deployment account
  run: terragrunt apply tfplan.binary
```

Alternatively, use manual assume-role if you need more control:

```yaml
- name: Assume role in deployment account
  run: |
    CREDS=$(aws sts assume-role \
      --role-arn arn:aws:iam::515048895906:role/DeploymentTarget-Terraform \
      --role-session-name deployment-${{ github.run_id }} \
      --external-id github-actions-deployment-2025)

    echo "AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .Credentials.AccessKeyId)" >> $GITHUB_ENV
    echo "AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .Credentials.SecretAccessKey)" >> $GITHUB_ENV
    echo "AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Credentials.SessionToken)" >> $GITHUB_ENV
```

## Security Considerations

### Branch Protection
- Only `main` branch and pull requests can use the OIDC role
- Protect `main` branch with required reviews and status checks

### Environment Protection
Use GitHub Environments for production deployments:

```yaml
jobs:
  deploy:
    environment: production  # Requires manual approval
    runs-on: ubuntu-latest
    # ...
```

### External ID
The cross-account role assumption requires external ID: `github-actions-deployment-2025`

Change this to a secure random value and update:
1. `environments/aws/root/deployment/github-oidc/terragrunt.hcl`
2. Target account role trust policies

### Plan Artifacts

Best practices for plan file management:

1. **Always use `-out` flag**: `terragrunt plan -out=tfplan.binary`
2. **Apply the binary plan**: `terragrunt apply tfplan.binary` (no `-auto-approve` needed)
3. **Generate human-readable version**: `terragrunt show tfplan.binary > tfplan.txt` for PR reviews
4. **Short retention**: 7 days is sufficient (plans are only needed until applied)

**Security benefit**: Prevents malicious changes between plan approval and apply.

### Artifact Naming Convention

Use unique, traceable artifact names:
```yaml
PLAN_ARTIFACT_NAME: tfplan-${{ github.event.pull_request.number || github.run_number }}-${{ github.sha }}
```

This ties each artifact to:
- **PR number** (or run number for pushes)
- **Commit SHA** for exact traceability

### Session Duration
4-hour sessions are configured. For longer deployments:
1. Update `session_duration` in `github-oidc/terragrunt.hcl`
2. Re-apply the module: `terragrunt apply`

## Target Account Setup

For each account where GitHub Actions needs to deploy, create a role:

```hcl
resource "aws_iam_role" "deployment_target" {
  name = "DeploymentTarget-Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::793421532223:role/GitHubActionsDeploymentRole"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "github-actions-deployment-2025"
        }
      }
    }]
  })

  # Attach appropriate policies for deployment
}
```

## Troubleshooting

### "Not authorized to perform sts:AssumeRoleWithWebIdentity"
- Check the `allowed_subjects` in `github-oidc/terragrunt.hcl`
- Verify the workflow is running from an allowed branch
- Ensure `id-token: write` permission is set

### "Roles may not be assumed by root accounts"
- The OIDC role is in the management account
- Use cross-account assume-role to deploy to other accounts

### "Artifact not found" in apply job
- Verify the plan job completed successfully
- Check artifact name matches between upload and download
- Ensure plan and apply jobs use the same `PLAN_ARTIFACT_NAME` env var
- Artifacts are deleted after 7 days - verify PR was merged within retention period

### Plan file appears modified
- Plan artifacts are immutable - if checksums differ, investigate security incident
- Re-run plan job to generate fresh artifact
- Review GitHub audit logs for artifact access

### Session expired
- Default session is 4 hours
- For longer runs, increase `session_duration` in the module

## Migration from Bootstrap Credentials

Once OIDC is verified working:

1. Test a deployment via GitHub Actions
2. Verify it completes successfully
3. Run cleanup script: `./scripts/cleanup-bootstrap.sh`
4. Keep permissions boundary for future use

The bootstrap user (`terraform-init-user`) and role (`terraform-bootstrap-role`) are only needed for initial setup and can be safely removed once OIDC is operational.

## References

- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS GitHub Actions](https://github.com/aws-actions/configure-aws-credentials)
