<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14,<2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0,<7.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region the module should target. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Logical environment name (e.g. root, dev, prod). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags applied to created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_module_metadata"></a> [module\_metadata](#output\_module\_metadata) | Basic information emitted by the placeholder module. |
<!-- END_TF_DOCS -->
