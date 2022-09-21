# terraform-aws-module-template
Template to use for Terraform module creation

## Dependencies (for developers)
A lot of checks are enforced for developers via `pre-commit`. For them to work,
you'll need the following dependencies:
- `tfsec`: For static code analysis.
- `terraform-docs`: To validate documentation
- `tflint`: To lint terraform files
- `terraform`: For `terraform fmt` and `terraform validate`.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.31.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.2.3 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 4.0.1 |
| <a name="module_elastic_beanstalk_environment"></a> [elastic\_beanstalk\_environment](#module\_elastic\_beanstalk\_environment) | app.terraform.io/PoolitInc/elastic-beanstalk-environment/aws | 0.47.0-security-2 |
| <a name="module_key_pair"></a> [key\_pair](#module\_key\_pair) | terraform-aws-modules/key-pair/aws | 1.0.1 |
| <a name="module_key_pair_secret"></a> [key\_pair\_secret](#module\_key\_pair\_secret) | cloudposse/ssm-parameter-store/aws | 0.9.1 |

## Resources

| Name | Type |
|------|------|
| [aws_elastic_beanstalk_application_version.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elastic_beanstalk_application_version) | resource |
| [aws_kms_key.docker_bucket_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.docker_run_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.docker_run_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_public_access_block.docker_run_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.docker_run_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_object.docker_run_object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [local_sensitive_file.docker_run_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [archive_file.docker_run](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.minimal_s3_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.poolit_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret.poolit_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.poolit_secret_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | n/a | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | n/a | yes |
| <a name="input_aws_secret_manager_name"></a> [aws\_secret\_manager\_name](#input\_aws\_secret\_manager\_name) | n/a | `string` | n/a | yes |
| <a name="input_db_endpoint"></a> [db\_endpoint](#input\_db\_endpoint) | n/a | `string` | n/a | yes |
| <a name="input_db_user_name"></a> [db\_user\_name](#input\_db\_user\_name) | n/a | `string` | n/a | yes |
| <a name="input_db_user_password"></a> [db\_user\_password](#input\_db\_user\_password) | n/a | `string` | n/a | yes |
| <a name="input_ecr_repository_tag"></a> [ecr\_repository\_tag](#input\_ecr\_repository\_tag) | n/a | `string` | n/a | yes |
| <a name="input_ecr_repository_url"></a> [ecr\_repository\_url](#input\_ecr\_repository\_url) | n/a | `string` | n/a | yes |
| <a name="input_elastic_beanstalk_application_name"></a> [elastic\_beanstalk\_application\_name](#input\_elastic\_beanstalk\_application\_name) | n/a | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_route53_zone_name"></a> [route53\_zone\_name](#input\_route53\_zone\_name) | Route53 Zone Name | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | n/a | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |
| <a name="input_web_command"></a> [web\_command](#input\_web\_command) | n/a | `string` | n/a | yes |
| <a name="input_web_container_port"></a> [web\_container\_port](#input\_web\_container\_port) | n/a | `string` | n/a | yes |
| <a name="input_web_environment_variables"></a> [web\_environment\_variables](#input\_web\_environment\_variables) | n/a | `map(any)` | n/a | yes |
| <a name="input_web_health_check_url"></a> [web\_health\_check\_url](#input\_web\_health\_check\_url) | n/a | `string` | n/a | yes |
| <a name="input_web_instance_type"></a> [web\_instance\_type](#input\_web\_instance\_type) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_version"></a> [application\_version](#output\_application\_version) | n/a |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | n/a |
| <a name="output_environment_name"></a> [environment\_name](#output\_environment\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
