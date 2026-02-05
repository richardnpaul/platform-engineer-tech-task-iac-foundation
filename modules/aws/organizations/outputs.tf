output "security_ou_id" {
  description = "ID of the Security OU"
  value       = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  description = "ID of the Infrastructure OU"
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "workloads_ou_id" {
  description = "ID of the Workloads OU"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "log_archive_account_id" {
  description = "ID of the Log Archive account"
  value       = aws_organizations_account.log_archive.id
}

output "audit_account_id" {
  description = "ID of the Security Audit account"
  value       = aws_organizations_account.audit.id
}

output "deployment_account_id" {
  description = "ID of the Deployment account"
  value       = aws_organizations_account.deployment.id
}

output "deployment_account_arn" {
  description = "ARN of the Deployment account"
  value       = aws_organizations_account.deployment.arn
}

output "dev_account_id" {
  description = "ID of the Development account"
  value       = aws_organizations_account.dev.id
}

output "dev_account_arn" {
  description = "ARN of the Development account"
  value       = aws_organizations_account.dev.arn
}
