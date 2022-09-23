locals {
  enabled   = module.this.enabled
  partition = join("", data.aws_partition.current.*.partition)
}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

#
# Service
#
data "aws_iam_policy_document" "service" {
  count = local.enabled ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "service" {
  count = local.enabled ? 1 : 0

  name               = "${module.this.id}-eb-service"
  assume_role_policy = join("", data.aws_iam_policy_document.service.*.json)
  tags               = module.this.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_health" {
  count = local.enabled && var.enhanced_reporting_enabled ? 1 : 0

  role       = join("", aws_iam_role.service.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "service" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.service.*.name)
  policy_arn = var.prefer_legacy_service_policy ? "arn:${local.partition}:iam::aws:policy/service-role/AWSElasticBeanstalkService" : "arn:${local.partition}:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

#
# EC2
#
data "aws_iam_policy_document" "ec2" {
  count = local.enabled ? 1 : 0

  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }

  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "elastic_beanstalk_multi_container_docker" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role" "ec2" {
  count = local.enabled ? 1 : 0

  name               = "${module.this.id}-${data.aws_region.current.name}-eb-ec2"
  assume_role_policy = join("", data.aws_iam_policy_document.ec2.*.json)
  tags               = module.this.tags
}

resource "aws_iam_role_policy" "default" {
  count = local.enabled ? 1 : 0

  name   = "${module.this.id}-${data.aws_region.current.name}-eb-default"
  role   = join("", aws_iam_role.ec2.*.id)
  policy = join("", data.aws_iam_policy_document.extended.*.json)
}

resource "aws_iam_role_policy_attachment" "web_tier" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "worker_tier" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "ssm_ec2" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = var.prefer_legacy_ssm_policy ? "arn:${local.partition}:iam::aws:policy/service-role/AmazonEC2RoleforSSM" : "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ssm_automation" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonSSMAutomationRole"

  lifecycle {
    create_before_destroy = true
  }
}

# http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/create_deploy_docker.container.console.html
# http://docs.aws.amazon.com/AmazonECR/latest/userguide/ecr_managed_policies.html#AmazonEC2ContainerRegistryReadOnly
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  count = local.enabled ? 1 : 0

  role       = join("", aws_iam_role.ec2.*.name)
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_ssm_activation" "ec2" {
  count = local.enabled ? 1 : 0

  name               = module.this.id
  iam_role           = join("", aws_iam_role.ec2.*.id)
  registration_limit = var.autoscale_max
  tags               = module.this.tags
}


data "aws_region" "current" {}

data "aws_iam_policy_document" "default" {
  count = local.enabled ? 1 : 0

  statement {
    actions = [
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetHealth",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:GetConsoleOutput",
      "ec2:AssociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeSecurityGroups",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeNotificationConfigurations",
    ]

    resources = ["*"]

    effect = "Allow"
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.secrets_manager_kms_key_arn]
  }

  statement {
    sid = "AllowOperations"

    actions = [
      "autoscaling:AttachInstances",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DeleteScheduledAction",
      "autoscaling:DescribeAccountLimits",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeLoadBalancers",
      "autoscaling:DescribeNotificationConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeScheduledActions",
      "autoscaling:DetachInstances",
      "autoscaling:PutScheduledUpdateGroupAction",
      "autoscaling:ResumeProcesses",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:SetInstanceProtection",
      "autoscaling:SuspendProcesses",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "cloudwatch:PutMetricAlarm",
      "ec2:AssociateAddress",
      "ec2:AllocateAddress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:TerminateInstances",
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:DescribeClusters",
      "ecs:RegisterTaskDefinition",
      "elasticbeanstalk:*",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "iam:ListRoles",
      "iam:PassRole",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
      "rds:DescribeDBEngineVersions",
      "rds:DescribeDBInstances",
      "rds:DescribeOrderableDBInstanceOptions",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:ListBucket",
      "sns:CreateTopic",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:Subscribe",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "codebuild:CreateProject",
      "codebuild:DeleteProject",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]

    effect = "Allow"
  }

  statement {
    sid = "AllowS3OperationsOnElasticBeanstalkBuckets"

    actions = [
      "s3:*"
    ]

    resources = [
      #bridgecrew:skip=BC_AWS_IAM_57:Skipping "Ensure IAM policies does not allow write access without constraint"
      #bridgecrew:skip=BC_AWS_IAM_56:Skipping "Ensure IAM policies do not allow permissions management / resource exposure without constraint"
      #bridgecrew:skip=BC_AWS_IAM_55:Skipping "Ensure IAM policies do not allow data exfiltration"
      "arn:${local.partition}:s3:::*"
    ]

    effect = "Allow"
  }

  statement {
    sid = "AllowDeleteCloudwatchLogGroups"

    actions = [
      "logs:DeleteLogGroup"
    ]

    resources = [
      "arn:${local.partition}:logs:*:*:log-group:/aws/elasticbeanstalk*"
    ]

    effect = "Allow"
  }

  statement {
    sid = "AllowCloudformationOperationsOnElasticBeanstalkStacks"

    actions = [
      "cloudformation:*"
    ]

    resources = [
      "arn:${local.partition}:cloudformation:*:*:stack/awseb-*",
      "arn:${local.partition}:cloudformation:*:*:stack/eb-*"
    ]

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "extended" {
  count = local.enabled ? 1 : 0

  source_json   = join("", data.aws_iam_policy_document.default.*.json)
  override_json = var.extended_ec2_policy_document
}

resource "aws_iam_instance_profile" "ec2" {
  count = local.enabled ? 1 : 0

  name = "${module.this.id}-eb-ec2"
  role = join("", aws_iam_role.ec2.*.name)
  tags = module.this.tags
}

locals {
  # Remove `Name` tag from the map of tags because Elastic Beanstalk generates the `Name` tag automatically
  # and if it is provided, terraform tries to recreate the application on each `plan/apply`
  # `Namespace` should be removed as well since any string that contains `Name` forces recreation
  # https://github.com/terraform-providers/terraform-provider-aws/issues/3963
  tags = { for t in keys(module.this.tags) : t => module.this.tags[t] if t != "Name" && t != "Namespace" }

  classic_elb_settings = [
    {
      namespace = "aws:elb:loadbalancer"
      name      = "CrossZone"
      value     = var.loadbalancer_crosszone
    },
    {
      namespace = "aws:elb:loadbalancer"
      name      = "SecurityGroups"
      value     = join(",", sort(var.loadbalancer_security_groups))
    },
    {
      namespace = "aws:elb:loadbalancer"
      name      = "ManagedSecurityGroup"
      value     = var.loadbalancer_managed_security_group
    },

    {
      namespace = "aws:elb:listener"
      name      = "ListenerProtocol"
      value     = "HTTP"
    },
    {
      namespace = "aws:elb:listener"
      name      = "InstancePort"
      value     = var.application_port
    },
    {
      namespace = "aws:elb:listener"
      name      = "ListenerEnabled"
      value     = var.http_listener_enabled || var.loadbalancer_certificate_arn == "" ? "true" : "false"
    },
    {
      namespace = "aws:elb:listener:443"
      name      = "ListenerProtocol"
      value     = "HTTPS"
    },
    {
      namespace = "aws:elb:listener:443"
      name      = "InstancePort"
      value     = var.application_port
    },
    {
      namespace = "aws:elb:listener:443"
      name      = "SSLCertificateId"
      value     = var.loadbalancer_certificate_arn
    },
    {
      namespace = "aws:elb:listener:443"
      name      = "ListenerEnabled"
      value     = var.loadbalancer_certificate_arn == "" ? "false" : "true"
    },
    {
      namespace = "aws:elb:listener:${var.ssh_listener_port}"
      name      = "ListenerProtocol"
      value     = "TCP"
    },
    {
      namespace = "aws:elb:listener:${var.ssh_listener_port}"
      name      = "InstancePort"
      value     = "22"
    },
    {
      namespace = "aws:elb:listener:${var.ssh_listener_port}"
      name      = "ListenerEnabled"
      value     = var.ssh_listener_enabled
    },
    {
      namespace = "aws:elb:policies"
      name      = "ConnectionSettingIdleTimeout"
      value     = var.loadbalancer_connection_idle_timeout
    },
    {
      namespace = "aws:elb:policies"
      name      = "ConnectionDrainingEnabled"
      value     = "true"
    },
  ]

  generic_alb_settings = [
    {
      namespace = "aws:elbv2:loadbalancer"
      name      = "SecurityGroups"
      value     = join(",", sort(var.loadbalancer_security_groups))
    }
  ]

  shared_alb_settings = [
    {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerIsShared"
      value     = "true"
    },
    {
      namespace = "aws:elbv2:loadbalancer"
      name      = "SharedLoadBalancer"
      value     = var.shared_loadbalancer_arn
    }
  ]

  alb_settings = [
    {
      namespace = "aws:elbv2:loadbalancer"
      name      = "AccessLogsS3Bucket"
      value     = !var.loadbalancer_is_shared ? join("", sort(aws_s3_bucket.elb_logs.*.id)) : ""
    },
    {
      namespace = "aws:elbv2:loadbalancer"
      name      = "AccessLogsS3Enabled"
      value     = "true"
    },
    {
      namespace = "aws:elbv2:listener:default"
      name      = "ListenerEnabled"
      value     = var.http_listener_enabled || var.loadbalancer_certificate_arn == "" ? "true" : "false"
    },
    {
      namespace = "aws:elbv2:loadbalancer"
      name      = "ManagedSecurityGroup"
      value     = var.loadbalancer_managed_security_group
    },
    {
      namespace = "aws:elbv2:listener:443"
      name      = "ListenerEnabled"
      value     = var.loadbalancer_certificate_arn == "" ? "false" : "true"
    },
    {
      namespace = "aws:elbv2:listener:443"
      name      = "Protocol"
      value     = "HTTPS"
    },
    {
      namespace = "aws:elbv2:listener:443"
      name      = "SSLCertificateArns"
      value     = var.loadbalancer_certificate_arn
    },
    {
      namespace = "aws:elbv2:listener:443"
      name      = "SSLPolicy"
      value     = var.loadbalancer_type == "application" ? var.loadbalancer_ssl_policy : ""
    },
    ###===================== Application Load Balancer Health check settings =====================================================###
    # The Application Load Balancer health check does not take into account the Elastic Beanstalk health check path
    # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-applicationloadbalancer.html
    # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-applicationloadbalancer.html#alb-default-process.config
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "HealthCheckPath"
      value     = var.healthcheck_url
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "MatcherHTTPCode"
      value     = join(",", sort(var.healthcheck_httpcodes_to_match))
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "HealthCheckTimeout"
      value     = var.healthcheck_timeout
    }
  ]

  nlb_settings = [
    {
      namespace = "aws:elbv2:listener:default"
      name      = "ListenerEnabled"
      value     = var.http_listener_enabled
    }
  ]

  # Settings for all loadbalancer types (including shared ALB)
  generic_elb_settings = [
    {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerType"
      value     = var.loadbalancer_type
    }
  ]

  # Settings for beanstalk managed elb only (so not for shared ALB)
  beanstalk_elb_settings = [
    {
      namespace = "aws:ec2:vpc"
      name      = "ELBSubnets"
      value     = join(",", sort(var.loadbalancer_subnets))
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "Port"
      value     = var.application_port
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "Protocol"
      value     = var.loadbalancer_type == "network" ? "TCP" : "HTTP"
    },
    {
      namespace = "aws:ec2:vpc"
      name      = "ELBScheme"
      value     = var.environment_type == "LoadBalanced" ? var.elb_scheme : ""
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "HealthCheckInterval"
      value     = var.healthcheck_interval
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "HealthyThresholdCount"
      value     = var.healthcheck_healthy_threshold_count
    },
    {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "UnhealthyThresholdCount"
      value     = var.healthcheck_unhealthy_threshold_count
    }
  ]

  # Select elb configuration depending on loadbalancer_type
  elb_settings_nlb        = var.loadbalancer_type == "network" ? concat(local.nlb_settings, local.generic_elb_settings, local.beanstalk_elb_settings) : []
  elb_settings_alb        = var.loadbalancer_type == "application" && !var.loadbalancer_is_shared ? concat(local.alb_settings, local.generic_alb_settings, local.generic_elb_settings, local.beanstalk_elb_settings) : []
  elb_settings_shared_alb = var.loadbalancer_type == "application" && var.loadbalancer_is_shared ? concat(local.shared_alb_settings, local.generic_alb_settings, local.generic_elb_settings) : []
  elb_setting_classic     = var.loadbalancer_type == "classic" ? concat(local.classic_elb_settings, local.generic_elb_settings, local.beanstalk_elb_settings) : []

  # If the tier is "WebServer" add the elb_settings, otherwise exclude them
  elb_settings_final = var.tier == "WebServer" ? concat(local.elb_settings_nlb, local.elb_settings_alb, local.elb_settings_shared_alb, local.elb_setting_classic) : []
}

#
# Full list of options:
# http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-elasticbeanstalkmanagedactionsplatformupdate
#
resource "aws_elastic_beanstalk_environment" "default" {
  count = local.enabled ? 1 : 0

  name                   = module.this.id
  application            = var.elastic_beanstalk_application_name
  description            = var.description
  tier                   = var.tier
  solution_stack_name    = var.solution_stack_name
  wait_for_ready_timeout = var.wait_for_ready_timeout
  version_label          = var.version_label
  tags                   = local.tags

  dynamic "setting" {
    for_each = local.elb_settings_final
    content {
      namespace = setting.value["namespace"]
      name      = setting.value["name"]
      value     = setting.value["value"]
      resource  = ""
    }
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = var.associate_public_ip_address
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", sort(var.application_subnets))
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = join(",", compact(sort(concat([module.aws_security_group.id], var.associated_security_group_ids))))
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = join("", aws_iam_instance_profile.ec2.*.name)
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Availability Zones"
    value     = var.availability_zone_selector
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = var.environment_type
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = join("", aws_iam_role.service.*.name)
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "BASE_HOST"
    value     = module.this.name
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = var.enhanced_reporting_enabled ? "enhanced" : "basic"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = var.managed_actions_enabled ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.autoscale_min
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.autoscale_max
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "EnableCapacityRebalancing"
    value     = var.enable_capacity_rebalancing
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = var.rolling_update_enabled
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = var.rolling_update_type
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MinInstancesInService"
    value     = var.updating_min_in_service
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = var.deployment_policy
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MaxBatchSize"
    value     = var.updating_max_batch
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = var.instance_type
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "EnableSpot"
    value     = var.enable_spot_instances ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotFleetOnDemandBase"
    value     = var.spot_fleet_on_demand_base
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotFleetOnDemandAboveBasePercentage"
    value     = var.spot_fleet_on_demand_above_base_percentage == -1 ? (var.environment_type == "LoadBalanced" ? 70 : 0) : var.spot_fleet_on_demand_above_base_percentage
    resource  = ""
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "SpotMaxPrice"
    value     = var.spot_max_price == -1 ? "" : var.spot_max_price
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = var.keypair
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = var.root_volume_size
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = var.root_volume_type
    resource  = ""
  }

  dynamic "setting" {
    for_each = var.root_volume_throughput == null ? [] : [var.root_volume_throughput]
    content {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "RootVolumeThroughput"
      value     = setting.value
      resource  = ""
    }
  }

  dynamic "setting" {
    for_each = var.root_volume_iops == null ? [] : [var.root_volume_iops]
    content {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "RootVolumeIOPS"
      value     = setting.value
      resource  = ""
    }
  }

  dynamic "setting" {
    for_each = var.ami_id == null ? [] : [var.ami_id]
    content {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "ImageId"
      value     = setting.value
      resource  = ""
    }
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = var.deployment_batch_size_type
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = var.deployment_batch_size
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "IgnoreHealthCheck"
    value     = var.deployment_ignore_health_check
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = var.deployment_timeout
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = var.preferred_start_time
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = var.update_level
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "InstanceRefreshEnabled"
    value     = var.instance_refresh_enabled
    resource  = ""
  }

  ###=========================== Autoscale trigger ========================== ###

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = var.autoscale_measure_name
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Statistic"
    value     = var.autoscale_statistic
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = var.autoscale_unit
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = var.autoscale_lower_bound
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerBreachScaleIncrement"
    value     = var.autoscale_lower_increment
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = var.autoscale_upper_bound
    resource  = ""
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperBreachScaleIncrement"
    value     = var.autoscale_upper_increment
    resource  = ""
  }

  ###=========================== Scheduled Actions ========================== ###

  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "MinSize"
      value     = setting.value.minsize
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "MaxSize"
      value     = setting.value.maxsize
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "DesiredCapacity"
      value     = setting.value.desiredcapacity
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "Recurrence"
      value     = setting.value.recurrence
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "StartTime"
      value     = setting.value.starttime
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "EndTime"
      value     = setting.value.endtime
      resource  = setting.value.name
    }
  }
  dynamic "setting" {
    for_each = var.scheduled_actions
    content {
      namespace = "aws:autoscaling:scheduledaction"
      name      = "Suspend"
      value     = setting.value.suspend ? "true" : "false"
      resource  = setting.value.name
    }
  }


  ###=========================== Logging ========================== ###

  setting {
    namespace = "aws:elasticbeanstalk:hostmanager"
    name      = "LogPublicationControl"
    value     = var.enable_log_publication_control ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = var.enable_stream_logs ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = var.logs_delete_on_terminate ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = var.logs_retention_in_days
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "HealthStreamingEnabled"
    value     = var.health_streaming_enabled ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "DeleteOnTerminate"
    value     = var.health_streaming_delete_on_terminate ? "true" : "false"
    resource  = ""
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "RetentionInDays"
    value     = var.health_streaming_retention_in_days
    resource  = ""
  }

  # Add additional Elastic Beanstalk settings
  # For full list of options, see https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html
  dynamic "setting" {
    for_each = var.additional_settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
      resource  = ""
    }
  }

  # dynamic needed as "spot max price" should only have a value if it is defined.
  dynamic "setting" {
    for_each = var.spot_max_price == -1 ? [] : [var.spot_max_price]
    content {
      namespace = "aws:ec2:instances"
      name      = "SpotMaxPrice"
      value     = var.spot_max_price
      resource  = ""
    }
  }

  # Add environment variables if provided
  dynamic "setting" {
    for_each = var.env_vars
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
      resource  = ""
    }
  }
}

data "aws_elb_service_account" "main" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" ? 1 : 0
}

data "aws_iam_policy_document" "elb_logs" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0

  statement {
    sid = ""

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:${local.partition}:s3:::${aws_s3_bucket.elb_logs[0].bucket}/*"
    ]

    principals {
      type        = "AWS"
      identifiers = [join("", data.aws_elb_service_account.main.*.arn)]
    }

    effect = "Allow"
  }
}
# The following are ignored because either (a) the discrepancies are intended or (b) these are covered in a block below.
#tfsec:ignore:aws-s3-block-public-acls
#tfsec:ignore:aws-s3-block-public-policy
#tfsec:ignore:aws-s3-ignore-public-acls
#tfsec:ignore:aws-s3-no-public-buckets
#tfsec:ignore:aws-s3-enable-bucket-logging
#tfsec:ignore:aws-s3-specify-public-access-block
#tfsec:ignore:aws-s3-enable-bucket-logging
#tfsec:ignore:aws-s3-encryption-customer-key
#tfsec:ignore:aws-s3-enable-versioning
#tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "elb_logs" {
  count         = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0
  bucket_prefix = "${module.this.id}-eb-lb-"
  force_destroy = var.force_destroy
  tags          = module.this.tags
}

# Result #5 HIGH Bucket does not encrypt data with a customer managed key.
# This is not a big deal for ELB logs, having an encryption with the default key should be enough for this.
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "elb_logs" {
  count  = var.s3_bucket_encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.elb_logs[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "elb_logs" {
  count  = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0
  bucket = aws_s3_bucket.elb_logs[0].bucket
  versioning_configuration {
    status = var.s3_bucket_versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_logging" "elb_logs" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared && var.s3_bucket_access_log_bucket_name != "" ? 1 : 0

  bucket        = aws_s3_bucket.elb_logs[0].bucket
  target_bucket = var.s3_bucket_access_log_bucket_name
  target_prefix = "logs/${module.this.id}"
}

resource "aws_s3_bucket_public_access_block" "elb_logs" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0

  bucket = aws_s3_bucket.elb_logs[0].bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "elb_logs" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0

  bucket = aws_s3_bucket.elb_logs[0].bucket
  acl    = "private"
}

resource "aws_s3_bucket_policy" "elb_logs" {
  count = local.enabled && var.tier == "WebServer" && var.environment_type == "LoadBalanced" && var.loadbalancer_type != "network" && !var.loadbalancer_is_shared ? 1 : 0

  bucket = aws_s3_bucket.elb_logs[0].bucket
  policy = join("", data.aws_iam_policy_document.elb_logs.*.json)
}

module "dns_hostname" {
  source  = "cloudposse/route53-cluster-hostname/aws"
  version = "0.12.2"

  enabled = local.enabled && var.dns_zone_id != "" && var.tier == "WebServer" ? true : false

  dns_name = var.dns_subdomain != "" ? var.dns_subdomain : module.this.name
  zone_id  = var.dns_zone_id
  records  = [join("", aws_elastic_beanstalk_environment.default.*.cname)]

  context = module.this.context
}
