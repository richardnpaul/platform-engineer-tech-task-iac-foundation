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
| [aws_organizations_account.audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.deployment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_account.log_archive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_organizational_unit.infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.workloads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_audit_email"></a> [audit\_email](#input\_audit\_email) | Email address for the Security Audit account | `string` | n/a | yes |
| <a name="input_deployment_email"></a> [deployment\_email](#input\_deployment\_email) | Email address for the Deployment/CI-CD account | `string` | n/a | yes |
| <a name="input_dev_email"></a> [dev\_email](#input\_dev\_email) | Email address for the Development account | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., production, staging) | `string` | `"production"` | no |
| <a name="input_log_archive_email"></a> [log\_archive\_email](#input\_log\_archive\_email) | Email address for the Log Archive account | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_audit_account_id"></a> [audit\_account\_id](#output\_audit\_account\_id) | ID of the Security Audit account |
| <a name="output_deployment_account_arn"></a> [deployment\_account\_arn](#output\_deployment\_account\_arn) | ARN of the Deployment account |
| <a name="output_deployment_account_id"></a> [deployment\_account\_id](#output\_deployment\_account\_id) | ID of the Deployment account |
| <a name="output_dev_account_arn"></a> [dev\_account\_arn](#output\_dev\_account\_arn) | ARN of the Development account |
| <a name="output_dev_account_id"></a> [dev\_account\_id](#output\_dev\_account\_id) | ID of the Development account |
| <a name="output_infrastructure_ou_id"></a> [infrastructure\_ou\_id](#output\_infrastructure\_ou\_id) | ID of the Infrastructure OU |
| <a name="output_log_archive_account_id"></a> [log\_archive\_account\_id](#output\_log\_archive\_account\_id) | ID of the Log Archive account |
| <a name="output_security_ou_id"></a> [security\_ou\_id](#output\_security\_ou\_id) | ID of the Security OU |
| <a name="output_workloads_ou_id"></a> [workloads\_ou\_id](#output\_workloads\_ou\_id) | ID of the Workloads OU |
<!-- END_TF_DOCS -->
