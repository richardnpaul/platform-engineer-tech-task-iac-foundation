# GitHub OIDC Provider for AWS
#
# Creates an OIDC identity provider for GitHub Actions and associated IAM role
# with scoped trust policy and permissions boundary

terraform {
  required_version = ">= 1.5"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    # GitHub's OIDC thumbprint (valid as of 2024, verify periodically)
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = var.tags
}

# Permissions boundary to prevent privilege escalation
resource "aws_iam_policy" "github_actions_boundary" {
  name        = "GitHubActionsPermissionsBoundary"
  description = "Permissions boundary for GitHub Actions OIDC role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeRole"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Resource = "arn:aws:iam::*:role/DeploymentTarget-*"
      },
      {
        Sid    = "AllowReadOnlyOrganizations"
        Effect = "Allow"
        Action = [
          "organizations:Describe*",
          "organizations:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyBoundaryModification"
        Effect = "Deny"
        Action = [
          "iam:DeleteRolePermissionsBoundary",
          "iam:PutRolePermissionsBoundary"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDangerousActions"
        Effect = "Deny"
        Action = [
          "iam:CreateAccessKey",
          "iam:CreateUser",
          "iam:DeleteUser",
          "organizations:LeaveOrganization",
          "account:CloseAccount"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = "OIDC role for GitHub Actions deployments from ${var.github_org}/${var.github_repo}"
  max_session_duration = var.session_duration
  permissions_boundary = aws_iam_policy.github_actions_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Restrict to specific repository and branches
            "token.actions.githubusercontent.com:sub" = var.allowed_subjects
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Inline policy allowing cross-account role assumption
resource "aws_iam_role_policy" "github_actions_deployment" {
  name = "DeploymentAccess"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeDeploymentRoles"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          for account_id in var.target_account_ids :
          "arn:aws:iam::${account_id}:role/DeploymentTarget-*"
        ]
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      },
      {
        Sid    = "ReadOrganizationStructure"
        Effect = "Allow"
        Action = [
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:DescribeOrganizationalUnit"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*"
        ]
      }
    ]
  })
}
