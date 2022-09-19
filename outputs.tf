output "endpoint" {
  value = module.elastic_beanstalk_environment.endpoint
}
output "environment_name" {
  value = module.elastic_beanstalk_environment.name
}
output "application_version" {
  value = aws_elastic_beanstalk_application_version.default.name
}