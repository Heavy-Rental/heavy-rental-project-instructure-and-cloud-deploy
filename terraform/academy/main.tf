# Academy / Vocareum estate — feat/infra-academy-estate (HR-161).
# Resources live in vpc.tf, nat.tf, security_groups.tf, alb.tf,
# compute.tf, rds.tf, secrets.tf, ecr.tf, observe.tf.
#
# Forbidden in this root: aws_iam_role, tls_private_key, key_name,
# aws_secretsmanager_secret_version, Marketplace AMIs,
# CloudTrail cloud_watch_logs_*, flow-log iam_role_arn.
# Guests use LabInstanceProfile → LabRole (data sources only).
# NAT is two aws_nat_gateway (one per public AZ), not an aws_instance.
