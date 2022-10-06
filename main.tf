locals {
  docker_run_config_sha = sha256(local_sensitive_file.docker_run_config.content)
  data_dog_agent_port   = "8126"
  secrets_container     = var.aws_secret_manager_name
  creds                 = jsondecode(data.aws_secretsmanager_secret_version.poolit_secret_instance.secret_string)
  service_image         = "${var.ecr_repository_url}:${var.stage}-${var.ecr_repository_tag}"
  application_port      = "80"
  name                  = "${var.stage_prefix}-${var.application_name}"
  poolit_domain         = coalesce(var.route53_zone_name, "poolit.com")
  service_domain        = "api"
  ami_id                = var.ami_id != null ? var.ami_id : null
}

resource "local_sensitive_file" "docker_run_config" {
  content = yamlencode({
    version = "3.8"
    services = {
      web = {
        image   = local.service_image
        command = var.web_command
        environment = merge({
          DATABASE_HOST       = var.db_endpoint
          SECRET_NAME         = local.secrets_container
          DD_SERVICE          = "${var.application_name}-${var.stage}"
          DD_ENV              = var.stage
          DD_AGENT_HOST       = "agent"
          DD_TRACE_AGENT_PORT = local.data_dog_agent_port
          DD_LOGS_INJECTION   = "true"
          }, var.web_environment_variables, nonsensitive(local.creds),
          {
            DATABASE_PASSWORD = nonsensitive(var.db_user_password)
            DATABASE_USERNAME = nonsensitive(var.db_user_name)
        })
        ports = ["${local.application_port}:${var.web_container_port}"]
        labels = {
          "com.datadoghq.ad.logs" = "[{\"source\": \"python\", \"service\": \"poolit\"}]"
        }
        restart = "always"
        healthcheck = {
          test     = "curl --fail -s http://localhost:${var.web_container_port}${var.web_health_check_url} || exit 1"
          interval = "1m30s"
          timeout  = "10s"
          retries  = "3"
        }
      }
      agent = {
        image = "datadog/agent:latest"
        ports = ["${local.data_dog_agent_port}:${local.data_dog_agent_port}"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "/proc/:/host/proc/:ro",
          "/opt/datadog-agent/run:/opt/datadog-agent/run:rw",
          "/sys/fs/cgroup/:/host/sys/fs/cgroup:ro"
        ]
        environment = {
          DD_API_KEY                           = nonsensitive(local.creds["DD_API_KEY"])
          DD_APM_ENABLED                       = "true"
          DD_APM_NON_LOCAL_TRAFFIC             = "true"
          DD_LOGS_ENABLED                      = "true"
          DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL = "true"
          DD_CONTAINER_EXCLUDE_LOGS            = "name:agent"
        }
      }
    }
  })
  filename = "${path.module}/docker-compose.yml"
}

data "archive_file" "docker_run" {
  type        = "zip"
  source_file = local_sensitive_file.docker_run_config.filename
  output_path = "${path.module}/Dockerrun.aws.zip"
}

data "aws_iam_policy_document" "minimal_s3_permissions" {
  statement {
    sid = "AllowOperationsOnElasticBeanstalkBuckets"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }
}

data "aws_secretsmanager_secret" "poolit_secrets" {
  name = local.secrets_container
}

data "aws_secretsmanager_secret_version" "poolit_secret_instance" {
  secret_id = data.aws_secretsmanager_secret.poolit_secrets.id
}

data "aws_route53_zone" "poolit_zone" {
  name = local.poolit_domain
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "4.0.1"

  domain_name = local.poolit_domain
  zone_id     = data.aws_route53_zone.poolit_zone.zone_id

  subject_alternative_names = [
    "*.${local.poolit_domain}",
    "${local.service_domain}.${local.poolit_domain}",
  ]

  wait_for_validation = true
}

# Compress the docker run config file
# Refer to data reference setup

# Create s3 bucket to store my docker run config
#tfsec:ignore:aws-s3-enable-versioning      # No need for versioning.
#tfsec:ignore:aws-s3-enable-bucket-logging  # No need for bucket logging.
resource "aws_s3_bucket" "docker_run_bucket" {
  bucket        = "${var.stage_prefix}-poolit-docker-run-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docker_run_bucket" {
  bucket = aws_s3_bucket.docker_run_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.docker_bucket_kms.arn
    }
  }
}

resource "aws_s3_bucket_acl" "docker_run_bucket" {
  bucket = aws_s3_bucket.docker_run_bucket.bucket
  acl    = "private"
}

resource "aws_kms_key" "docker_bucket_kms" {
  description             = "KMS Key for Docker Run bucket"
  deletion_window_in_days = 30

  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  enable_key_rotation = true
}

resource "aws_kms_alias" "docker_bucket_kms_key_alias" {
  name          = "alias/${var.stage_prefix}-poolit-docker-run-bucket-key"
  target_key_id = aws_kms_key.docker_bucket_kms.key_id
}

resource "aws_s3_bucket_public_access_block" "docker_run_bucket" {
  bucket = aws_s3_bucket.docker_run_bucket.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create s3 object from the compressed docker run config
resource "aws_s3_object" "docker_run_object" {
  key                    = "${local.docker_run_config_sha}.zip"
  bucket                 = aws_s3_bucket.docker_run_bucket.id
  source                 = data.archive_file.docker_run.output_path
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.docker_bucket_kms.arn
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  version    = "1.0.1"
  key_name   = "/poolit/${var.stage_prefix}/ebs-key-pair"
  public_key = tls_private_key.this.public_key_openssh
}

module "key_pair_secret" {
  source = "cloudposse/ssm-parameter-store/aws"
  # Cloud Posse recommends pinning every module to a specific version
  version = "0.9.1"

  parameter_write = [
    {
      name        = "/poolit/${var.stage_prefix}/app/elb/key_pair_public_key"
      value       = tls_private_key.this.public_key_openssh
      type        = "String"
      overwrite   = "true"
      description = "Elastic beanstalk ssh public key"
    },
    {
      name        = "/poolit/${var.stage_prefix}/app/elb/key_pair_private_key_pem"
      value       = tls_private_key.this.private_key_pem
      type        = "String"
      overwrite   = "true"
      description = "Elastic beanstalk ssh private key"
    },
    {
      name        = "/poolit/${var.stage_prefix}/app/elb/database_url"
      value       = var.db_endpoint
      type        = "String"
      overwrite   = "true"
      description = "Database endpoint"
    },
    {
      name        = "/poolit/${var.stage_prefix}/app/elb/database_username"
      value       = var.db_user_name
      type        = "String"
      overwrite   = "true"
      description = "Database username"
    },
    {
      name        = "/poolit/${var.stage_prefix}/app/elb/database_password"
      value       = var.db_user_password
      type        = "String"
      overwrite   = "true"
      description = "Database password"
    }
  ]
}

data "aws_elastic_beanstalk_solution_stack" "latest_docker" {
  most_recent = true
  # Ie. "64bit Amazon Linux 2 v3.4.19 running Docker"
  name_regex = "^64bit Amazon Linux (.*) (.*) running Docker$"
}

# Create eb version
#tfsec:ignore:aws-s3-enable-versioning
module "elastic_beanstalk_environment" {
  source                             = "app.terraform.io/PoolitInc/elastic-beanstalk-environment/aws"
  version                            = "0.47.0-security-6"
  region                             = var.aws_region
  name                               = local.name
  elastic_beanstalk_application_name = var.elastic_beanstalk_application_name
  solution_stack_name                = data.aws_elastic_beanstalk_solution_stack.latest_docker.name
  environment_type                   = "LoadBalanced"
  loadbalancer_type                  = "application"
  tier                               = "WebServer"
  application_port                   = local.application_port
  vpc_id                             = var.vpc_id
  loadbalancer_subnets               = var.public_subnet_ids
  application_subnets                = var.private_subnet_ids
  deployment_policy                  = "Immutable"
  rolling_update_type                = "Immutable"
  allow_all_egress                   = true
  force_destroy                      = true
  keypair                            = module.key_pair.key_pair_key_name
  instance_type                      = var.web_instance_type
  healthcheck_url                    = var.web_health_check_url
  s3_bucket_versioning_enabled       = false
  extended_ec2_policy_document       = data.aws_iam_policy_document.minimal_s3_permissions.json
  ssh_listener_enabled               = true
  associate_public_ip_address        = false
  deployment_ignore_health_check     = false
  dns_subdomain                      = local.service_domain
  dns_zone_id                        = data.aws_route53_zone.poolit_zone.zone_id
  loadbalancer_certificate_arn       = module.acm.acm_certificate_arn
  loadbalancer_ssl_policy            = "ELBSecurityPolicy-FS-2018-06"
  aws_account_id                     = var.aws_account_id
  secrets_manager_kms_key_arn        = var.secrets_manager_kms_key_arn
  ami_id                             = local.ami_id
  #https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html
  depends_on = [
    module.key_pair
  ]
}

resource "aws_elastic_beanstalk_application_version" "default" {
  name        = "${local.name}-${var.ecr_repository_tag}"
  application = var.elastic_beanstalk_application_name
  description = "application version created by terraform for ${local.service_image}"
  bucket      = aws_s3_bucket.docker_run_bucket.id
  key         = aws_s3_object.docker_run_object.id
  depends_on = [
    module.elastic_beanstalk_environment
  ]
}
