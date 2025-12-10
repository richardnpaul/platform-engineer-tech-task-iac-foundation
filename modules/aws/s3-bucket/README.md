# S3 Bucket Module

Reusable Terraform module for creating S3 buckets with security best practices.

## Features

- ✅ SSE-S3 encryption (AES256) by default
- ✅ Public access blocked by default
- ✅ Configurable versioning
- ✅ Flexible lifecycle rules
- ✅ Bucket key enabled for encryption efficiency
- ✅ Optional force destroy for dev/test environments

## Usage

```hcl
module "my_bucket" {
  source = "../../modules/aws/s3-bucket"

  bucket_name        = "my-application-data"
  versioning_enabled = true
  force_destroy      = false  # Protect production data

  lifecycle_rules = [
    {
      id      = "cleanup-old-data"
      enabled = true
      prefix  = "temp/"
      expiration_days = 7
    }
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `bucket_name` | Name of the S3 bucket | `string` | - | Yes |
| `versioning_enabled` | Enable versioning for the bucket | `bool` | `false` | No |
| `lifecycle_rules` | List of lifecycle rules | `list(object)` | `[]` | No |
| `force_destroy` | Allow deletion of non-empty bucket | `bool` | `false` | No |
| `tags` | Tags to apply to the bucket | `map(string)` | `{}` | No |

### Lifecycle Rule Object

```hcl
{
  id      = string                        # Rule identifier
  enabled = bool                          # Enable/disable rule
  prefix  = optional(string, "")          # Object prefix filter
  expiration_days = optional(number)      # Days until expiration
  noncurrent_version_expiration_days = optional(number)  # Version cleanup
  abort_incomplete_multipart_upload_days = optional(number, 7)  # Cleanup failed uploads
}
```

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | The name of the bucket |
| `bucket_arn` | The ARN of the bucket |
| `bucket_domain_name` | The bucket domain name |
| `bucket_regional_domain_name` | The bucket region-specific domain name |
| `module_metadata` | Module metadata for observability |

## Security

### Encryption
- **SSE-S3 (AES256):** AWS-managed encryption keys
- **Bucket key enabled:** Reduces encryption costs by up to 99%
- **No customer-managed keys:** Simplifies key management

### Access Control
- **Public access blocked:** All 4 public access settings enabled
- **No bucket ACLs:** Rely on bucket policies and IAM
- **Encryption enforced:** All objects encrypted at rest

### Best Practices Applied
1. Encryption at rest enabled by default
2. Public access completely blocked
3. Versioning optional (enable for critical data)
4. Lifecycle rules prevent cost creep
5. Force destroy optional (disable for production)

## Examples

### Plan Storage Bucket (No Versioning, Short Lifecycle)

```hcl
module "plan_storage" {
  source = "../../modules/aws/s3-bucket"

  bucket_name        = "terraform-plans"
  versioning_enabled = false
  force_destroy      = true

  lifecycle_rules = [
    {
      id              = "cleanup-old-plans"
      enabled         = true
      expiration_days = 14
    }
  ]
}
```

### State Storage Bucket (Versioned, No Lifecycle)

```hcl
module "state_storage" {
  source = "../../modules/aws/s3-bucket"

  bucket_name        = "terraform-state"
  versioning_enabled = true
  force_destroy      = false

  tags = {
    Critical = "true"
    Backup   = "required"
  }
}
```

### Archive Bucket (Transition to Glacier)

```hcl
# Note: Glacier transitions not currently supported
# Extend module with transition rules if needed
```

## Cost Optimization

1. **Bucket key enabled:** Reduces encryption API calls by 99%
2. **Lifecycle rules:** Automatically delete old objects
3. **No versioning:** Reduces storage (use only when needed)
4. **Abort incomplete uploads:** Cleans up failed uploads after 7 days

## Maintenance

- Module compatible with AWS provider `~> 5.0`
- Requires Terraform `>= 1.5`
- No external dependencies beyond AWS provider

## Testing

```bash
# Initialize and plan
cd environments/aws/root/plan-storage
terragrunt init
terragrunt plan

# Apply
terragrunt apply

# Verify bucket
aws s3 ls s3://iac-foundation-tf-plans/
```
