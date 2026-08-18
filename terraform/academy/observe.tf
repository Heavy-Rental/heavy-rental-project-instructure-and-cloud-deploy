# Operate / Monitor (AWS study §2.1). Vocareum: no new IAM.
# LabRole is data-sourced (ADR 0005 / 0015). Do not attach it to CloudTrail
# or VPC flow-log delivery — LabRole trusts EC2, not those services.
# Trail and flow logs use S3 + bucket policy (service principals).

check "observe_uses_labrole" {
  assert {
    condition = var.deployment != "academy" || (
      length(data.aws_iam_role.lab) == 1 &&
      data.aws_iam_role.lab[0].name == var.lab_role_name &&
      data.aws_iam_instance_profile.lab[0].role_name == var.lab_role_name
    )
    error_message = "Academy observe/estate must use Vocareum LabRole via LabInstanceProfile. Do not create IAM."
  }
}

check "paid_uses_created_profiles" {
  assert {
    condition     = var.deployment != "actual" || length(aws_iam_instance_profile.guest) == 4
    error_message = "AWS_ACTUAL deployment must create four hr-paid-* instance profiles. Do not use LabRole."
  }
}

resource "aws_s3_bucket" "observe" {
  bucket        = local.observe_bucket
  force_destroy = true

  tags = {
    Name = "heavy-rental-observe"
    Role = "observe"
  }
}

resource "aws_s3_bucket_public_access_block" "observe" {
  bucket                  = aws_s3_bucket.observe.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "observe" {
  bucket = aws_s3_bucket.observe.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "observe" {
  bucket = aws_s3_bucket.observe.id

  rule {
    id     = "expire-14d"
    status = "Enabled"

    filter {}

    expiration {
      days = 14
    }
  }
}

resource "aws_s3_bucket_policy" "observe" {
  bucket = aws_s3_bucket.observe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.observe.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/heavy-rental-academy"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.observe.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/heavy-rental-academy"
          }
        }
      },
      {
        Sid       = "ALBAccessLogsAcl"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.observe.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "ALBAccessLogsWrite"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.observe.arn}/alb/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "VpcFlowLogsAcl"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.observe.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "VpcFlowLogsWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.observe.arn}/vpc-flow/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
    ]
  })
}

# S3 only. Do not set cloud_watch_logs_* (Vocareum + ADR 0015).
resource "aws_cloudtrail" "academy" {
  name                          = "heavy-rental-academy"
  s3_bucket_name                = aws_s3_bucket.observe.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  enable_logging                = true
  is_organization_trail         = false

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.observe]

  tags = {
    Name = "heavy-rental-academy"
    Role = "observe"
  }
}

# S3 destination — no iam_role_arn (do not pass LabRole).
resource "aws_flow_log" "academy" {
  vpc_id               = aws_vpc.academy.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${aws_s3_bucket.observe.arn}/vpc-flow/"

  destination_options {
    file_format                = "plain-text"
    hive_compatible_partitions = false
    per_hour_partition         = false
  }

  tags = {
    Name = "heavy-rental-academy-flow"
    Role = "observe"
  }

  depends_on = [aws_s3_bucket_policy.observe]
}

resource "aws_sns_topic" "alarms" {
  name = "hr-academy-alarms"

  tags = {
    Name = "hr-academy-alarms"
    Role = "observe"
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_group" "app" {
  for_each          = local.log_group_apps
  name              = "/heavy-rental/${each.key}"
  retention_in_days = 14

  tags = {
    Name = "/heavy-rental/${each.key}"
    Role = "observe"
  }
}

locals {
  alb_alarms = {
    portal = {
      lb = aws_lb.portal.arn_suffix
      tg = aws_lb_target_group.portal.arn_suffix
    }
    rest = {
      lb = aws_lb.rest.arn_suffix
      tg = aws_lb_target_group.rest.arn_suffix
    }
    haystack = {
      lb = aws_lb.haystack.arn_suffix
      tg = aws_lb_target_group.haystack.arn_suffix
    }
  }

  rds_alarms = {
    sor = {
      id   = aws_db_instance.heavy_rental.identifier
      name = "hr-rds-sor"
    }
    haystack = {
      id   = aws_db_instance.haystack.identifier
      name = "hr-rds-haystack"
    }
  }

  asg_alarms = {
    portal   = aws_autoscaling_group.portal.name
    rest     = aws_autoscaling_group.rest.name
    haystack = aws_autoscaling_group.haystack.name
    neo4j    = aws_autoscaling_group.neo4j.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each            = local.alb_alarms
  alarm_name          = "hr-alb-${each.key}-5xx"
  alarm_description   = "Target 5xx on hr-alb-${each.key} (name only; not an internal DNS)."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = each.value.lb
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  for_each            = local.alb_alarms
  alarm_name          = "hr-alb-${each.key}-unhealthy"
  alarm_description   = "Unhealthy hosts on tg-${each.key}."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = each.value.lb
    TargetGroup  = each.value.tg
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each            = local.rds_alarms
  alarm_name          = "${each.value.name}-cpu"
  alarm_description   = "CPU over 80 percent on ${each.value.id}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = each.value.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  for_each            = local.rds_alarms
  alarm_name          = "${each.value.name}-storage"
  alarm_description   = "Free storage under 2 GiB on ${each.value.id}."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = each.value.id
  }
}

resource "aws_cloudwatch_metric_alarm" "asg_inservice" {
  for_each            = local.asg_alarms
  alarm_name          = "hr-asg-${each.key}-inservice"
  alarm_description   = "InService count below 2 on ${each.value}."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Average"
  threshold           = 2
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    AutoScalingGroupName = each.value
  }
}

resource "aws_cloudwatch_dashboard" "estate" {
  dashboard_name = "heavy-rental-academy"
  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "ALB 5xx (sum/5m)"
            region = data.aws_region.current.name
            stat   = "Sum"
            period = 300
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.portal.arn_suffix, { label = "portal" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.rest.arn_suffix, { label = "rest" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.haystack.arn_suffix, { label = "haystack" }],
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "ALB p99 target response time"
            region = data.aws_region.current.name
            stat   = "p99"
            period = 300
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.portal.arn_suffix, { label = "portal" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.rest.arn_suffix, { label = "rest" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.haystack.arn_suffix, { label = "haystack" }],
            ]
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "Unhealthy hosts"
            region = data.aws_region.current.name
            stat   = "Maximum"
            period = 60
            metrics = [
              ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.portal.arn_suffix, "TargetGroup", aws_lb_target_group.portal.arn_suffix, { label = "portal" }],
              ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.rest.arn_suffix, "TargetGroup", aws_lb_target_group.rest.arn_suffix, { label = "rest" }],
              ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.haystack.arn_suffix, "TargetGroup", aws_lb_target_group.haystack.arn_suffix, { label = "haystack" }],
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "RDS CPU"
            region = data.aws_region.current.name
            stat   = "Average"
            period = 300
            metrics = [
              ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.heavy_rental.identifier, { label = "sor" }],
              ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.haystack.identifier, { label = "haystack" }],
            ]
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "RDS free storage"
            region = data.aws_region.current.name
            stat   = "Average"
            period = 300
            metrics = [
              ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.heavy_rental.identifier, { label = "sor" }],
              ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.haystack.identifier, { label = "haystack" }],
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "ASG InService"
            region = data.aws_region.current.name
            stat   = "Average"
            period = 300
            metrics = [
              ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.portal.name, { label = "portal" }],
              ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.rest.name, { label = "rest" }],
              ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.haystack.name, { label = "haystack" }],
              ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.neo4j.name, { label = "neo4j" }],
            ]
          }
        },
      ]
    )
  })
}
