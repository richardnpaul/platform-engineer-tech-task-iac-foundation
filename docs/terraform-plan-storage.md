# Terraform Plan Storage Strategy

## Overview

This document explains how Terraform plan files are stored and retrieved between GitHub Actions workflow runs to maintain Terraform best practices while working across separate PR and push events.

## Storage Infrastructure

**Single Bucket with Prefix Strategy:**
- **Bucket:** `iac-foundation-tf-state` (existing)
- **Region:** `eu-west-1`
- **Encryption:** SSE-S3 (AES256) - AWS-managed keys
- **State storage:** Root of bucket (versioned, no lifecycle)
- **Plan storage:** `terraform-plans/` prefix (no versioning, 14-day lifecycle)
- **Cost:** No additional bucket, minimal incremental cost

**Why Single Bucket?**
- ✅ Simpler: No new infrastructure needed
- ✅ Existing IAM permissions already grant access
- ✅ Prefix-based lifecycle rules isolate plan cleanup from state
- ✅ Same encryption and access controls
- ✅ Reduced operational complexity

## The Problem

GitHub Actions artifacts are **scoped to individual workflow runs**:
- When a PR is created/updated, a workflow run generates and uploads plan artifacts
- When the PR is merged to main, a **new separate workflow run** is triggered
- The second workflow run cannot access artifacts from the first run
- This breaks the standard Terraform workflow: `plan` → review → `apply` using the same plan file

## The Solution: Prefix-Based Plan Storage

We use the existing state bucket (`iac-foundation-tf-state`) with a dedicated `terraform-plans/` prefix and lifecycle rule to store plan files between workflow runs.

### Plan Job (PR Event)

**When:** Pull request created or updated

**Actions:**
1. Generate Terraform plans for all stacks:
   - `environments/aws/root/deployment/github-oidc/tfplan.binary`
   - `environments/aws/dev/vpc/tfplan.binary`
   - `environments/aws/dev/eks-mgmt/tfplan.binary`
   - `environments/aws/dev/eks-apps/tfplan.binary`

2. Upload plans to GitHub artifacts (7-day retention, for PR review convenience)

3. Upload plans to S3:
   ```
   s3://iac-foundation-tf-state/terraform-plans/{PR_NUMBER}/{COMMIT_SHA}/github-oidc.tfplan.binary
   s3://iac-foundation-tf-state/terraform-plans/{PR_NUMBER}/{COMMIT_SHA}/vpc.tfplan.binary
   s3://iac-foundation-tf-state/terraform-plans/{PR_NUMBER}/{COMMIT_SHA}/eks-mgmt.tfplan.binary
   s3://iac-foundation-tf-state/terraform-plans/{PR_NUMBER}/{COMMIT_SHA}/eks-apps.tfplan.binary
   ```

4. Comment on PR with:
   - Formatted plan output (collapsed sections)
   - S3 location for reference
   - Deployment order

### Apply Job (Push to Main)

**When:** PR merged to main

**Actions:**
1. Extract PR number from merge commit message:
   ```bash
   git log -1 --pretty=%B | grep -oP 'Merge pull request #\K\d+'
   ```
   - GitHub's default merge commit format: "Merge pull request #X from ..."
   - Gracefully handles squash/rebase merges (PR number will be empty)

2. Download plans from S3 (if PR number found):
   ```bash
   aws s3 cp s3://iac-foundation-tf-state/terraform-plans/${PR_NUM}/${COMMIT_SHA}/github-oidc.tfplan.binary \
     environments/aws/root/deployment/github-oidc/tfplan.binary
   # ... repeat for all stacks
   ```

3. Apply infrastructure:
   ```bash
   if [ -f tfplan.binary ]; then
     # Use the exact plan from PR review
     terragrunt apply tfplan.binary
   else
     # Fallback: fresh plan and apply (for manual pushes or squash merges)
     terragrunt apply -auto-approve
   fi
   ```

## Key Design Decisions

### 1. S3 Key Structure

```
s3://iac-foundation-tf-state/
  ├── env/            # Terraform state files (versioned, no lifecycle)
  └── terraform-plans/  # Plan files (14-day lifecycle)
      ├── {PR_NUMBER}/
      │   └── {COMMIT_SHA}/
      │       ├── github-oidc.tfplan.binary
      │       ├── vpc.tfplan.binary
      │       ├── eks-mgmt.tfplan.binary
      │       └── eks-apps.tfplan.binary
```

**Rationale:**
- `terraform-plans/` prefix isolates plan storage from state storage
- Lifecycle rule targets only this prefix (state files unaffected)
- PR number groups all plans for a given PR together
- Commit SHA ensures exact version match between plan and apply
- Flat file structure (no subdirectories per stack) simplifies download logic
- Extension `.tfplan.binary` makes file purpose obvious

### 2. Graceful Degradation

Plans might not be found in S3 if:
- PR was squashed/rebased (loses PR number in commit message)
- Direct push to main (no PR workflow)
- S3 upload failed during plan job
- Plan files expired/deleted

**Fallback:** Run fresh `terragrunt plan` + `apply -auto-approve`

This maintains safety through manual approval gate (production environment) even without plan file.

### 3. Error Handling

All S3 operations use `|| true` or `|| echo "warning"`:
- Upload failures don't block PR workflow (GitHub artifacts still available for review)
- Download failures don't block apply workflow (graceful degradation)
- Both operations log clear warnings for troubleshooting

## Storage Lifecycle

### Current Configuration

The `iac-foundation-tf-state` bucket has a prefix-based lifecycle policy:

```hcl
lifecycle_rule {
  id      = "cleanup-terraform-plans"
  enabled = true

  filter {
    prefix = "terraform-plans/"  # Only apply to plans, not state
  }

  expiration {
    days = 14  # Delete plans older than 14 days
  }

  abort_incomplete_multipart_upload {
    days = 1  # Clean up failed uploads
  }
}
```

**Rationale:**
- Prefix filter ensures state files are never deleted
- 14 days sufficient for most debugging scenarios
- Plans are immutable (once applied, historical versions not needed)
- Automatic cleanup prevents S3 cost creep
- Aligned with 7-day GitHub artifact retention

### Cost Estimation

**Monthly Storage:**
- 4 stacks × 4 PRs/month × ~50KB/plan = ~800KB
- Storage: ~$0.00002/month (negligible)

**Lifecycle Cleanup:**
- API calls for lifecycle actions: Free (included with S3 lifecycle)

**Total:** < $0.01/month + negligible data transfer

**Note:** No separate bucket fees since we use existing infrastructure.

## Best Practices Maintained

✅ **Plan file review:** PR reviewers see exact plan that will be applied

✅ **No drift:** Apply uses the same plan file, preventing unexpected changes

✅ **Audit trail:** S3 stores plans with PR number and commit SHA for traceability

✅ **Rollback capability:** Old plans available for 30 days for investigation

✅ **Manual approval:** Production environment gate prevents accidental applies

## Alternative Approaches Considered

### 1. GitHub Artifacts Only
**Rejected:** Artifacts don't transfer between workflow runs

### 2. Terraform Cloud Remote Runs
**Rejected:** Requires paid plan, adds external dependency

### 3. Re-plan on Apply
**Rejected:** Violates Terraform best practices, risks drift between review and apply

### 4. Database Storage (DynamoDB)
**Rejected:** Overcomplicated, S3 sufficient for binary blobs

## Monitoring and Troubleshooting

### Check if Plan Was Used

Look for log output in apply job:
```
📦 Using plan from artifact  # Plan found and used
⚠️  No plan artifact found, running fresh plan and apply  # Fallback used
```

### Verify S3 Upload

Check S3 bucket after PR workflow:
```bash
aws s3 ls s3://iac-foundation-tf-state/terraform-plans/{PR_NUMBER}/{COMMIT_SHA}/
```

Should show 4 plan files with timestamps.

### Debug PR Number Extraction

In apply job logs, look for:
```
✅ Found PR number: 123  # Successful extraction
⚠️  Could not extract PR number from merge commit  # Fallback to fresh apply
```

## Security Considerations

### IAM Permissions Required

**Plan Job (PR event):**
- `s3:PutObject` on `iac-foundation-tf-state/terraform-plans/*`
- Existing state read permissions on `iac-foundation-tf-state/env/*`

**Apply Job (Push event):**
- `s3:GetObject` on `iac-foundation-tf-state/terraform-plans/*`
- Existing state read/write permissions on `iac-foundation-tf-state/env/*`

**Note:** If the GitHub Actions OIDC role already has `s3:*` or broad bucket permissions, no changes needed.

### Plan File Security

**Risks:**
- Plan files may contain sensitive data (secrets, private IPs, ARNs)
- Stored in same bucket as state files

**Mitigations:**
- Bucket has SSE-S3 encryption at rest enabled
- Bucket policy restricts access to GitHub Actions OIDC role
- Public access completely blocked via bucket policy
- 14-day lifecycle policy limits exposure window
- Plans don't contain more sensitive data than state files
- Prefix isolation allows independent lifecycle management

## Future Enhancements

1. ✅ **Lifecycle Policy:** Implemented - 14-day automatic cleanup with prefix filter
2. ✅ **Single Bucket:** Using existing state bucket with prefix isolation
3. **Plan Validation:** Add checksums to verify plan integrity
4. **Multi-Region:** Consider cross-region replication for DR
5. **Metrics:** Track plan file size, usage rates, storage costs per prefix
6. **Alerts:** Notify if plan upload/download fails repeatedly
7. **Access Logging:** Enable S3 access logs for audit trail
8. **Separate Bucket:** Consider dedicated bucket if access patterns diverge

## References

- [Terraform Plan Documentation](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [GitHub Actions Artifacts Limitations](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
