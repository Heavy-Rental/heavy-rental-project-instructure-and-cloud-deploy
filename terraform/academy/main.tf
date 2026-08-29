# Academy / Vocareum estate — feat/infra-academy-estate (HR-161).
# Resources live in vpc.tf, nat.tf, security_groups.tf, alb.tf,
# compute.tf, rds.tf, secrets.tf, ecr.tf, observe.tf.
#
# Forbidden in this root: tls_private_key, key_name,
# aws_secretsmanager_secret_version, Marketplace AMIs,
# CloudTrail cloud_watch_logs_*, flow-log iam_role_arn.
# Academy: LabInstanceProfile → LabRole (data sources only). No aws_iam_role.
# AWS_ACTUAL: iam.tf creates hr-paid-* instance profiles.
# NAT is two aws_nat_gateway (one per public AZ), not an aws_instance.
# REST ALB is internet-facing in public subnets (ADR 0018). Haystack stays internal.
# hr-bastion (ADR 0021) is a single EC2 SSH jump; no ASG; no :22 from 0.0.0.0/0.
