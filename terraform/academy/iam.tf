# Paid only. Academy guests stay on Vocareum LabInstanceProfile / LabRole (ADR 0005).

locals {
  paid_secret_arn = {
    portal   = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:heavy-rental/portal-*"
    rest     = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:heavy-rental/rest-*"
    haystack = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:heavy-rental/haystack-*"
    neo4j    = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:heavy-rental/neo4j-*"
  }

  instance_profile_name = {
    for app in local.guest_apps :
    app => (
      local.is_academy
      ? data.aws_iam_instance_profile.lab[0].name
      : aws_iam_instance_profile.guest[app].name
    )
  }
}

data "aws_iam_policy_document" "guest_assume" {
  count = local.is_actual ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "guest" {
  for_each           = local.is_actual ? local.guest_apps : toset([])
  name               = "hr-paid-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.guest_assume[0].json

  tags = {
    Name = "hr-paid-${each.key}"
    Role = each.key
  }
}

resource "aws_iam_role_policy_attachment" "guest_ssm" {
  for_each   = aws_iam_role.guest
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "guest_app" {
  for_each = aws_iam_role.guest
  name     = "hr-paid-${each.key}-app"
  role     = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/heavy-rental-*"
      },
      {
        Sid      = "OwnSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = local.paid_secret_arn[each.key]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "guest" {
  for_each = aws_iam_role.guest
  name     = "hr-paid-${each.key}"
  role     = each.value.name
}
