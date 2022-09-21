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

variable "route53_zone_name" {
  type        = string
  description = "Route53 Zone Name"
  default     = null
}
