# AWS Organizations Structure
#
# This module sets up the foundational AWS Organizations structure:
# - Organizational Units (OUs)
# - Core AWS accounts (Security, Infrastructure)
# - Service Control Policies (SCPs)
#
# Note: AWS Control Tower can be layered on top of this structure if needed

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

# Get the organization root ID
data "aws_organizations_organization" "current" {}

locals {
  organization_root_id = data.aws_organizations_organization.current.roots[0].id
}

# Root Organizational Units
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.organization_root_id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.organization_root_id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.organization_root_id
  tags      = var.tags
}

# Core Security Accounts
resource "aws_organizations_account" "log_archive" {
  name      = "Log Archive"
  email     = var.log_archive_email
  parent_id = aws_organizations_organizational_unit.security.id

  role_name = "OrganizationAccountAccessRole"
  tags = merge(var.tags, {
    Purpose = "Centralized logging"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "audit" {
  name      = "Security Audit"
  email     = var.audit_email
  parent_id = aws_organizations_organizational_unit.security.id

  role_name = "OrganizationAccountAccessRole"
  tags = merge(var.tags, {
    Purpose = "Security auditing and compliance"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Deployment/Tooling Account for CI/CD
resource "aws_organizations_account" "deployment" {
  name      = "Deployment"
  email     = var.deployment_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  role_name = "OrganizationAccountAccessRole"
  tags = merge(var.tags, {
    Purpose = "CI/CD and infrastructure automation"
  })

  lifecycle {
    prevent_destroy = true
  }
}
