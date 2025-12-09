# Build permissions boundary to prevent privilege escalation
BOUNDARY_POLICY=$(jq -n \
  --arg accountId "${ACCOUNT_ID}" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "AllowBootstrapServices",
        Effect: "Allow",
        Action: [
          "organizations:*",
          "iam:*",
          "sts:*",
          "s3:*",
          "dynamodb:*",
          "cloudformation:*",
          "servicecatalog:*",
          "sso:*",
          "sso-directory:*",
          "identitystore:*",
          "config:*",
          "cloudtrail:*",
          "cloudwatch:*",
          "logs:*",
          "kms:*",
          "sns:*",
          "lambda:*",
          "ec2:Describe*",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateTags",
          "controltower:*"
        ],
        Resource: "*"
      },
      {
        Sid: "DenyBoundaryModification",
        Effect: "Deny",
        Action: [
          "iam:DeleteUserPermissionsBoundary",
          "iam:PutUserPermissionsBoundary",
          "iam:DeleteRolePermissionsBoundary",
          "iam:PutRolePermissionsBoundary"
        ],
        Resource: "*"
      },
      {
        Sid: "DenyUnboundedIAMCreation",
        Effect: "Deny",
        Action: [
          "iam:CreateUser",
          "iam:CreateRole"
        ],
        Resource: "*",
        Condition: {
          "StringNotEquals": {
            "iam:PermissionsBoundary": ("arn:aws:iam::" + $accountId + ":policy/terraform-init-permissions-boundary")
          }
        }
      }
    ]
  }')

# Build trust policy for terraform-bootstrap-role
ROLE_TRUST_POLICY=$(jq -n \
  --arg userArn "arn:aws:iam::${ACCOUNT_ID}:user/terraform-init-user" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          AWS: $userArn
        },
        Action: "sts:AssumeRole",
        Condition: {
          StringEquals: {
            "sts:ExternalId": "terraform-bootstrap"
          }
        }
      }
    ]
  }')

# Build minimal user policy allowing only assume-role
USER_ASSUME_ROLE_POLICY=$(jq -n \
  --arg accountId "${ACCOUNT_ID}" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "AssumeBootstrapRole",
        Effect: "Allow",
        Action: "sts:AssumeRole",
        Resource: ("arn:aws:iam::" + $accountId + ":role/terraform-bootstrap-role")
      }
    ]
  }')

# Build role policy with actual bootstrap permissions
ROLE_POLICY=$(jq -n \
  --arg bucket "arn:aws:s3:::${BUCKET}" \
  --arg bucketObjects "arn:aws:s3:::${BUCKET}/*" \
  --arg accountId "${ACCOUNT_ID}" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "StateManagement",
        Effect: "Allow",
        Action: [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:GetBucketEncryption"
        ],
        Resource: [ $bucket, $bucketObjects ]
      },
      {
        Sid: "OrganizationsFullAccess",
        Effect: "Allow",
        Action: "organizations:*",
        Resource: "*"
      },
      {
        Sid: "IAMBootstrapAccess",
        Effect: "Allow",
        Action: [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:CreateServiceLinkedRole",
          "iam:PassRole"
        ],
        Resource: "*"
      },
      {
        Sid: "ControlTowerAccess",
        Effect: "Allow",
        Action: [
          "controltower:*",
          "cloudformation:*",
          "servicecatalog:*"
        ],
        Resource: "*"
      },
      {
        Sid: "IdentityCenterAccess",
        Effect: "Allow",
        Action: [
          "sso:*",
          "sso-directory:*",
          "identitystore:*"
        ],
        Resource: "*"
      },
      {
        Sid: "LoggingAndMonitoring",
        Effect: "Allow",
        Action: [
          "config:*",
          "cloudtrail:*",
          "cloudwatch:*",
          "logs:*"
        ],
        Resource: "*"
      },
      {
        Sid: "KMSForEncryption",
        Effect: "Allow",
        Action: [
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:EnableKeyRotation",
          "kms:ListAliases",
          "kms:TagResource"
        ],
        Resource: "*"
      },
      {
        Sid: "NetworkingForLandingZone",
        Effect: "Allow",
        Action: [
          "ec2:Describe*",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:AssociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup"
        ],
        Resource: "*"
      },
      {
        Sid: "SNSForNotifications",
        Effect: "Allow",
        Action: [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:SetTopicAttributes",
          "sns:GetTopicAttributes"
        ],
        Resource: "*"
      },
      {
        Sid: "LambdaForAutomation",
        Effect: "Allow",
        Action: [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission"
        ],
        Resource: "*"
      }
    ]
  }')
