output "module_metadata" {
  description = "Basic information emitted by the placeholder module."
  value = {
    environment = var.environment
    region      = var.aws_region
    tags        = var.tags
    note        = "No infrastructure created yet"
  }
}
