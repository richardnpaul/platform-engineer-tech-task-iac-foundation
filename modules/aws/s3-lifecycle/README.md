<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14,<2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0,<7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0,<7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket_lifecycle_configuration.plans_cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the existing S3 bucket | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lifecycle_rule_id"></a> [lifecycle\_rule\_id](#output\_lifecycle\_rule\_id) | ID of the lifecycle rule |
| <a name="output_module_metadata"></a> [module\_metadata](#output\_module\_metadata) | Module metadata |
<!-- END_TF_DOCS -->
