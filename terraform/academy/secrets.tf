# Shells only. No aws_secretsmanager_secret_version (ADR 0006).

resource "aws_secretsmanager_secret" "app" {
  for_each                = local.secret_ids
  name                    = each.key
  recovery_window_in_days = 0

  tags = {
    Name = each.key
  }
}
