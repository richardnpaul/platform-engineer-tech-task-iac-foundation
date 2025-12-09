#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

PROVIDER=${1:-}
STATE_KEY=${2:-}
BUCKET=${3:-}
REGION=${4:-}
PROFILE=${5:-default}

log() {
  echo "[bootstrap-state] $*"
}

if [[ -z "${PROVIDER}" ]]; then
  log "No cloud provider supplied to bootstrap-state hook"
  exit 1
fi

if [[ "${PROVIDER}" != "aws" ]]; then
  log "Provider '${PROVIDER}' does not require bootstrap orchestration yet; skipping."
  exit 0
fi

if ! command -v aws >/dev/null 2>&1; then
  log "AWS CLI is not available in PATH; cannot verify/create state bucket."
  exit 1
fi

if [[ -z "${BUCKET}" ]]; then
  log "State bucket name missing. Export TG_STATE_BUCKET or adjust root.hcl."
  exit 1
fi

command -v aws >/dev/null 2>&1 || { log "AWS CLI not found in PATH; also ensure that you have jq, terraform and terragrunt installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { log "jq not found in PATH; also ensure that you have terraform and terragrunt installed"; exit 1; }
command -v terragrunt >/dev/null 2>&1 || { log "Terragrunt not found in PATH; also ensure that you have terraform installed"; exit 1; }
command -v terraform >/dev/null 2>&1 || { log "Terraform not found in PATH"; exit 1; }

AWS_ARGS=()
[[ -n "${PROFILE}" ]] && AWS_ARGS+=(--profile "${PROFILE}")
[[ -n "${REGION}" ]] && AWS_ARGS+=(--region "${REGION}")

# Test if we need to login first
if aws "${AWS_ARGS[@]}" sts get-caller-identity >/dev/null 2>&1; then
  log "AWS credentials appear to be already configured; skipping login."
else
  log "No AWS credentials found; initiating login..."
  aws login
  log "Temporary AWS credentials acquired."
fi

ACCOUNT_ID=$(aws "${AWS_ARGS[@]}" sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "")
if [[ -z "${ACCOUNT_ID}" || "${ACCOUNT_ID}" == "None" ]]; then
  log "Unable to determine AWS account ID for permissions setup."
  exit 1
fi

log "Ensuring S3 bucket '${BUCKET}' exists for Terraform state"
if ! aws "${AWS_ARGS[@]}" s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
  if [[ -n "${REGION}" && "${REGION}" != "us-east-1" ]]; then
    aws "${AWS_ARGS[@]}" s3api create-bucket --bucket "${BUCKET}" --create-bucket-configuration "LocationConstraint=${REGION}"
  else
    aws "${AWS_ARGS[@]}" s3api create-bucket --bucket "${BUCKET}"
  fi
  aws "${AWS_ARGS[@]}" s3api put-bucket-versioning --bucket "${BUCKET}" --versioning-configuration Status=Enabled
  aws "${AWS_ARGS[@]}" s3api put-bucket-encryption --bucket "${BUCKET}" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
else
  log "Bucket '${BUCKET}' already present"
fi

set +e
ORG_ARN=$(aws organizations describe-organization "${AWS_ARGS[@]}" --query 'Organization.Arn' --output text 2>/dev/null)
ORG_EXIT_CODE=$?
set -e

if [[ $ORG_EXIT_CODE -ne 0 ]]; then
  aws organizations create-organization "${AWS_ARGS[@]}" --feature-set ALL > /dev/null 2>&1
  log "AWS Organization created."
else
  log "AWS Organization already exists: ${ORG_ARN}"
fi

TF_INIT_USER=$(aws iam get-user "${AWS_ARGS[@]}" --user-name "terraform-init-user" --query 'User.Arn' --output text 2>/dev/null || echo "None")

if [[ "${TF_INIT_USER}" == "None" ]] || [[ -z "${TF_INIT_USER}" ]]; then
  log "Terraform init user does not exist; creating..."
  TF_INIT_USER=$(aws iam create-user "${AWS_ARGS[@]}" --user-name "terraform-init-user" --query 'User.Arn' --output text 2>/dev/null || echo "None")
  log "Terraform init user created: ${TF_INIT_USER}"
else
  log "Terraform init user already exists: ${TF_INIT_USER}"
fi

log "Setting up role-based permissions for terraform-init-user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/policies.sh"

BOUNDARY_FILE=$(mktemp)
ROLE_TRUST_FILE=$(mktemp)
ROLE_POLICY_FILE=$(mktemp)
USER_POLICY_FILE=$(mktemp)
printf '%s' "${BOUNDARY_POLICY}" > "${BOUNDARY_FILE}"
printf '%s' "${ROLE_TRUST_POLICY}" > "${ROLE_TRUST_FILE}"
printf '%s' "${ROLE_POLICY}" > "${ROLE_POLICY_FILE}"
printf '%s' "${USER_ASSUME_ROLE_POLICY}" > "${USER_POLICY_FILE}"

# Create or update permissions boundary
BOUNDARY_NAME="terraform-init-permissions-boundary"
BOUNDARY_ARN=$(aws iam list-policies "${AWS_ARGS[@]}" --scope Local --query "Policies[?PolicyName=='${BOUNDARY_NAME}'].Arn | [0]" --output text 2>/dev/null || echo "None")

if [[ "${BOUNDARY_ARN}" == "None" ]]; then
  BOUNDARY_ARN=$(aws iam create-policy "${AWS_ARGS[@]}" \
    --policy-name "${BOUNDARY_NAME}" \
    --policy-document "file://${BOUNDARY_FILE}" \
    --description "Permissions boundary for terraform-bootstrap-role preventing privilege escalation" \
    --query 'Policy.Arn' --output text)
  log "Created permissions boundary: ${BOUNDARY_NAME}"
else
  log "Updating permissions boundary: ${BOUNDARY_NAME}"
  set +e
  VERSION_COUNT=$(aws iam list-policy-versions "${AWS_ARGS[@]}" --policy-arn "${BOUNDARY_ARN}" --output json 2>/dev/null | jq -r '.Versions | length' 2>/dev/null || echo "0")
  set -e

  if [[ -z "${VERSION_COUNT}" || "${VERSION_COUNT}" == "null" ]]; then
    VERSION_COUNT=0
  fi

  if (( VERSION_COUNT >= 5 )); then
    set +e
    OLDEST=$(aws iam list-policy-versions "${AWS_ARGS[@]}" --policy-arn "${BOUNDARY_ARN}" --output json 2>/dev/null | jq -r '.Versions | sort_by(.CreateDate) | map(select(.IsDefaultVersion == false)) | .[0].VersionId' 2>/dev/null)
    set -e

    if [[ "${OLDEST}" != "null" && -n "${OLDEST}" ]]; then
      aws iam delete-policy-version "${AWS_ARGS[@]}" --policy-arn "${BOUNDARY_ARN}" --version-id "${OLDEST}" >/dev/null
      log "Deleted old policy version: ${OLDEST}"
    fi
  fi
  aws iam create-policy-version "${AWS_ARGS[@]}" --policy-arn "${BOUNDARY_ARN}" \
    --policy-document "file://${BOUNDARY_FILE}" --set-as-default >/dev/null
fi

# Create or update terraform-bootstrap-role
ROLE_NAME="terraform-bootstrap-role"
ROLE_ARN=$(aws iam get-role "${AWS_ARGS[@]}" --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text 2>/dev/null || echo "None")

if [[ "${ROLE_ARN}" == "None" ]]; then
  ROLE_ARN=$(aws iam create-role "${AWS_ARGS[@]}" \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${ROLE_TRUST_FILE}" \
    --permissions-boundary "${BOUNDARY_ARN}" \
    --description "Bootstrap role for Control Tower and landing zone setup" \
    --query 'Role.Arn' --output text)
  log "Created bootstrap role: ${ROLE_NAME}"
else
  log "Updating trust policy for role: ${ROLE_NAME}"
  aws iam update-assume-role-policy "${AWS_ARGS[@]}" \
    --role-name "${ROLE_NAME}" \
    --policy-document "file://${ROLE_TRUST_FILE}"
fi

# Attach permissions boundary to role if not already set
CURRENT_ROLE_BOUNDARY=$(aws iam get-role "${AWS_ARGS[@]}" --role-name "${ROLE_NAME}" \
  --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null || echo "None")

if [[ "${CURRENT_ROLE_BOUNDARY}" != "${BOUNDARY_ARN}" ]]; then
  aws iam put-role-permissions-boundary "${AWS_ARGS[@]}" \
    --role-name "${ROLE_NAME}" \
    --permissions-boundary "${BOUNDARY_ARN}" >/dev/null
  log "Attached permissions boundary to ${ROLE_NAME}"
else
  log "Permissions boundary already attached to role"
fi

# Apply bootstrap permissions to role
ROLE_POLICY_NAME="terraform-bootstrap-access"
aws iam put-role-policy "${AWS_ARGS[@]}" \
  --role-name "${ROLE_NAME}" \
  --policy-name "${ROLE_POLICY_NAME}" \
  --policy-document "file://${ROLE_POLICY_FILE}"
log "Applied bootstrap policy to role: ${ROLE_POLICY_NAME}"

# Apply minimal assume-role policy to user
USER_POLICY_NAME="terraform-init-assume-role"
aws iam put-user-policy "${AWS_ARGS[@]}" \
  --user-name "terraform-init-user" \
  --policy-name "${USER_POLICY_NAME}" \
  --policy-document "file://${USER_POLICY_FILE}"
log "Applied assume-role policy to terraform-init-user"

rm -f "${BOUNDARY_FILE}" "${ROLE_TRUST_FILE}" "${ROLE_POLICY_FILE}" "${USER_POLICY_FILE}"

log "Bootstrap role configured with scoped permissions for Control Tower + landing zone setup"
log "NEXT STEPS:"
log "  1. Create access keys for terraform-init-user: aws iam create-access-key --user-name terraform-init-user"
log "  2. Assume the bootstrap role to get temporary credentials:"
log "     aws sts assume-role --role-arn ${ROLE_ARN} --role-session-name bootstrap-session --external-id terraform-bootstrap"
log "  3. Export the temporary credentials (AccessKeyId, SecretAccessKey, SessionToken) from step 2"
log "  4. Use those session credentials to run Terragrunt stacks for Control Tower, OUs, deployment account"
log "  5. Create GitHub OIDC provider + role in deployment account for CI/CD"
log "  6. Delete terraform-init-user access keys once OIDC handoff is complete"

log "State backend ready for key '${STATE_KEY}'"
