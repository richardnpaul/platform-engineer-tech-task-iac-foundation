# GitHub OIDC Provider for AWS
#
# Creates an OIDC identity provider for GitHub Actions and associated IAM role
# with scoped trust policy and permissions boundary

terraform {
  required_version = ">= 1.14,<2.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0,<7.0"
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
        Sid    = "AllowTerraformStateAccess"
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
      },
      {
        Sid    = "AllowManageSelfIAM"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
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
    Statement = concat(
      [
        # Allow from main branch (for push events)
        {
          Sid    = "AllowMainBranch"
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
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
            }
          }
        },
        # Allow production environment only from main branch
        {
          Sid    = "AllowProductionEnvironmentFromMain"
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
              "token.actions.githubusercontent.com:ref" = "refs/heads/main"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:production"
            }
          }
        },
        # Allow dev/staging environments from pull requests
        {
          Sid    = "AllowNonProdEnvironmentsFromPullRequests"
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud"        = "sts.amazonaws.com"
              "token.actions.githubusercontent.com:event_name" = "pull_request"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = [
                "repo:${var.github_org}/${var.github_repo}:environment:dev",
                "repo:${var.github_org}/${var.github_repo}:environment:staging"
              ]
            }
          }
        }
      ],
      # Support legacy pull_request subject for backwards compatibility
      var.allow_legacy_pull_request ? [
        {
          Sid    = "AllowLegacyPullRequest"
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
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:pull_request"
            }
          }
        }
      ] : []
    )
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
          "organizations:DescribeAccount"
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
      },
      {
        Sid    = "ManageSelfIAMResources"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = [
          aws_iam_openid_connect_provider.github.arn,
          aws_iam_policy.github_actions_boundary.arn,
          aws_iam_role.github_actions.arn
        ]
      },
      {
        Sid    = "ManageVPCResources"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageELBResources"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageEKSResources"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:CreateFargateProfile",
          "eks:DeleteFargateProfile",
          "eks:DescribeFargateProfile",
          "eks:ListFargateProfiles",
          "eks:CreateAddon",
          "eks:DeleteAddon",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:UpdateAddon"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageEKSServiceLinkedRole"
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "arn:aws:iam::*:role/aws-service-role/eks.amazonaws.com/*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "eks.amazonaws.com"
          }
        }
      },
      {
        Sid    = "PassRoleToEKS"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "eks.amazonaws.com"
          }
        }
      }
    ]
  })
}
