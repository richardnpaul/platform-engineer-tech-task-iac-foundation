#!/usr/bin/env bash
#
# Assume terraform-bootstrap-role and export temporary credentials
# Usage: source ./scripts/assume-bootstrap-role.sh
#
# This script must be SOURCED, not executed, to export credentials to your shell

# Detect if we're being sourced or executed
(return 0 2>/dev/null) && SOURCED=1 || SOURCED=0

# Use set -e only if not sourced (to avoid killing the parent shell)
if [ "$SOURCED" -eq 0 ]; then
  set -euo pipefail
fi

ROLE_ARN="arn:aws:iam::793421532223:role/terraform-bootstrap-role"
SESSION_NAME="bootstrap-session"
EXTERNAL_ID="terraform-bootstrap"

echo "[assume-role] Assuming role: ${ROLE_ARN}"

# Assume the role and capture credentials
if ! CREDS=$(aws sts assume-role \
  --role-arn "${ROLE_ARN}" \
  --role-session-name "${SESSION_NAME}" \
  --external-id "${EXTERNAL_ID}" \
  --output json 2>&1); then
  echo "[assume-role] ✗ Failed to assume role:"
  echo "${CREDS}"
  [ "$SOURCED" -eq 1 ] && return 1 || exit 1
fi

# Extract and export credentials
if ! AWS_ACCESS_KEY_ID=$(echo "${CREDS}" | jq -r '.Credentials.AccessKeyId'); then
  echo "[assume-role] ✗ Failed to parse AccessKeyId"
  [ "$SOURCED" -eq 1 ] && return 1 || exit 1
fi

if ! AWS_SECRET_ACCESS_KEY=$(echo "${CREDS}" | jq -r '.Credentials.SecretAccessKey'); then
  echo "[assume-role] ✗ Failed to parse SecretAccessKey"
  [ "$SOURCED" -eq 1 ] && return 1 || exit 1
fi

if ! AWS_SESSION_TOKEN=$(echo "${CREDS}" | jq -r '.Credentials.SessionToken'); then
  echo "[assume-role] ✗ Failed to parse SessionToken"
  [ "$SOURCED" -eq 1 ] && return 1 || exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Unset profile so session credentials take precedence
unset AWS_PROFILE

EXPIRATION=$(echo "${CREDS}" | jq -r '.Credentials.Expiration')
IDENTITY=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'unknown')

echo "[assume-role] ✓ Role assumed successfully"
echo "[assume-role] Session expires at: ${EXPIRATION}"
echo "[assume-role] Using identity: ${IDENTITY}"
