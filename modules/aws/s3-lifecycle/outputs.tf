output "lifecycle_rule_id" {
  description = "ID of the lifecycle rule"
  value       = "cleanup-terraform-plans"
}

output "module_metadata" {
  description = "Module metadata"
  value = {
    bucket_name     = var.bucket_name
    prefix          = "terraform-plans/"
    expiration_days = 14
    rule_status     = "Enabled"
  }
}
