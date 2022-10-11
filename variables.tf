variable "application_name" {
  type = string
}
variable "elastic_beanstalk_application_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "stage" {
  type        = string
  description = "Stage to which the stack belongs"
}
variable "stage_prefix" {
  type        = string
  description = "Stage prefix to provision resources"
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "aws_secret_manager_name" {
  type = string
}
variable "temporal_cert_secret_name" {
  type = string
}
variable "temporal_key_secret_name" {
  type = string
}
variable "db_endpoint" {
  type = string
}
variable "db_user_name" {
  type      = string
  sensitive = true
}
variable "db_user_password" {
  type      = string
  sensitive = true
}
variable "ecr_repository_url" {
  type = string
}
variable "ecr_repository_tag" {
  type = string
}
variable "web_command" {
  type = string
}
variable "web_environment_variables" {
  type = map(any)
}
variable "web_container_port" {
  type = string
}
variable "web_instance_type" {
  type = string
}
variable "web_health_check_url" {
  type = string
}
variable "temporal_worker_command" {
  type = string
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 Zone Name"
  default     = null
}

variable "aws_account_id" {
  type        = string
  description = "AWS Account ID where resources will be created"
}

variable "secrets_manager_kms_key_arn" {
  type        = string
  description = "KMS Key ARN used to encrypt secrets in Secrets Manager"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID to run the elastic beanstalk nodes, leave empty for default"
  default     = null
}

variable "waf_enabled" {
  type        = bool
  description = "Whether WAF is enabled for this deployment"
  default     = false
}

variable "waf_acl_arn" {
  type        = string
  description = "The ARN of the WAF ACL to use if waf_enabled is set to true"
  default     = null
}
