#!/usr/bin/env bash
#
# Cleanup all bootstrap resources to start fresh
# WARNING: This will delete IAM users, roles, policies, S3 buckets, and Organizations
#
# Usage: ./scripts/cleanup-bootstrap.sh

set -o errexit
set -o nounset
set -o pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="iac-foundation-tf-state"
REGION="eu-west-1"

echo "[cleanup] Starting cleanup of bootstrap resources in account ${ACCOUNT_ID}"
echo "[cleanup] WARNING: This will delete IAM resources, S3 bucket, and potentially the AWS Organization"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
  echo "[cleanup] Aborted"
  exit 0
fi

# Delete access keys for terraform-init-user
echo "[cleanup] Deleting access keys for terraform-init-user..."
aws iam list-access-keys --user-name terraform-init-user --output json 2>/dev/null | \
  jq -r '.AccessKeyMetadata[].AccessKeyId' | \
  while read -r KEY_ID; do
    if [ -n "${KEY_ID}" ]; then
      aws iam delete-access-key --user-name terraform-init-user --access-key-id "${KEY_ID}" || true
      echo "[cleanup]   Deleted access key: ${KEY_ID}"
    fi
  done

# Detach policies from terraform-init-user
echo "[cleanup] Detaching policies from terraform-init-user..."
aws iam list-attached-user-policies --user-name terraform-init-user --output json 2>/dev/null | \
  jq -r '.AttachedPolicies[].PolicyArn' | \
  while read -r POLICY_ARN; do
    if [ -n "${POLICY_ARN}" ]; then
      aws iam detach-user-policy --user-name terraform-init-user --policy-arn "${POLICY_ARN}" || true
      echo "[cleanup]   Detached policy: ${POLICY_ARN}"
    fi
  done

# Delete inline policies from terraform-init-user
echo "[cleanup] Deleting inline policies from terraform-init-user..."
aws iam list-user-policies --user-name terraform-init-user --output json 2>/dev/null | \
  jq -r '.PolicyNames[]' | \
  while read -r POLICY_NAME; do
    if [ -n "${POLICY_NAME}" ]; then
      aws iam delete-user-policy --user-name terraform-init-user --policy-name "${POLICY_NAME}" || true
      echo "[cleanup]   Deleted inline policy: ${POLICY_NAME}"
    fi
  done

# Delete terraform-init-user
echo "[cleanup] Deleting terraform-init-user..."
aws iam delete-user --user-name terraform-init-user 2>/dev/null && \
  echo "[cleanup]   ✓ Deleted user: terraform-init-user" || \
  echo "[cleanup]   User does not exist or already deleted"

# Detach policies from terraform-bootstrap-role
echo "[cleanup] Detaching policies from terraform-bootstrap-role..."
aws iam list-attached-role-policies --role-name terraform-bootstrap-role --output json 2>/dev/null | \
  jq -r '.AttachedPolicies[].PolicyArn' | \
  while read -r POLICY_ARN; do
    if [ -n "${POLICY_ARN}" ]; then
      aws iam detach-role-policy --role-name terraform-bootstrap-role --policy-arn "${POLICY_ARN}" || true
      echo "[cleanup]   Detached policy: ${POLICY_ARN}"
    fi
  done

# Delete inline policies from terraform-bootstrap-role
echo "[cleanup] Deleting inline policies from terraform-bootstrap-role..."
aws iam list-role-policies --role-name terraform-bootstrap-role --output json 2>/dev/null | \
  jq -r '.PolicyNames[]' | \
  while read -r POLICY_NAME; do
    if [ -n "${POLICY_NAME}" ]; then
      aws iam delete-role-policy --role-name terraform-bootstrap-role --policy-name "${POLICY_NAME}" || true
      echo "[cleanup]   Deleted inline policy: ${POLICY_NAME}"
    fi
  done

# Delete terraform-bootstrap-role
echo "[cleanup] Deleting terraform-bootstrap-role..."
aws iam delete-role --role-name terraform-bootstrap-role 2>/dev/null && \
  echo "[cleanup]   ✓ Deleted role: terraform-bootstrap-role" || \
  echo "[cleanup]   Role does not exist or already deleted"

# Delete managed policies
for POLICY_NAME in terraform-init-permissions-boundary terraform-bootstrap-access; do
  echo "[cleanup] Deleting managed policy: ${POLICY_NAME}..."
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

  # Check if policy exists
  if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
    # Delete all non-default versions first
    aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --output json 2>/dev/null | \
      jq -r '.Versions[] | select(.IsDefaultVersion == false) | .VersionId' | \
      while read -r VERSION_ID; do
        if [ -n "${VERSION_ID}" ]; then
          aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${VERSION_ID}" || true
          echo "[cleanup]   Deleted policy version: ${VERSION_ID}"
        fi
      done

    # Delete the policy itself
    aws iam delete-policy --policy-arn "${POLICY_ARN}" 2>/dev/null && \
      echo "[cleanup]   ✓ Deleted policy: ${POLICY_NAME}" || \
      echo "[cleanup]   Failed to delete policy"
  else
    echo "[cleanup]   Policy does not exist or already deleted"
  fi
done

# Empty and delete S3 bucket
echo "[cleanup] Emptying and deleting S3 bucket: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
  # Delete all versions and delete markers
  aws s3api list-object-versions --bucket "${BUCKET_NAME}" --output json 2>/dev/null | \
    jq -r '.Versions[]?, .DeleteMarkers[]? | "\(.Key)\t\(.VersionId)"' | \
    while IFS=$'\t' read -r KEY VERSION_ID; do
      if [ -n "${KEY}" ] && [ -n "${VERSION_ID}" ]; then
        aws s3api delete-object --bucket "${BUCKET_NAME}" --key "${KEY}" --version-id "${VERSION_ID}" || true
      fi
    done

  aws s3 rb "s3://${BUCKET_NAME}" --force && \
    echo "[cleanup]   ✓ Deleted bucket: ${BUCKET_NAME}" || \
    echo "[cleanup]   Failed to delete bucket"
else
  echo "[cleanup]   Bucket does not exist or already deleted"
fi

# Clean up local Terragrunt cache
echo "[cleanup] Cleaning up local Terragrunt cache..."
find . -type d -name '.terragrunt-cache' -exec rm -rf {} + 2>/dev/null || true
find . -type d -name '.terraform' -exec rm -rf {} + 2>/dev/null || true
find . -type f -name '.terraform.lock.hcl' -delete 2>/dev/null || true
echo "[cleanup]   ✓ Cleaned local cache directories"

# Clean up credentials file
echo "[cleanup] Removing terraform-init profile from ~/.aws/credentials..."
if [ -f ~/.aws/credentials ]; then
  # Remove the [terraform-init] section
  sed -i '/^\[terraform-init\]/,/^$/d' ~/.aws/credentials 2>/dev/null || true
  echo "[cleanup]   ✓ Cleaned credentials file"
fi

echo ""
echo "[cleanup] ============================================"
echo "[cleanup] Cleanup complete!"
echo "[cleanup] ============================================"
echo "[cleanup] NOTE: AWS Organization was NOT deleted (requires manual action)"
echo "[cleanup] To delete the organization:"
echo "[cleanup]   1. Remove all member accounts"
echo "[cleanup]   2. Run: aws organizations delete-organization"
echo ""
echo "[cleanup] You can now run 'terragrunt init' to bootstrap from scratch"
