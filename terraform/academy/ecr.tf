# Optional in-region repos. LabRole on guests is pull-only.
# Push is the Vocareum console user / later runner step — not this apply.

resource "aws_ecr_repository" "app" {
  for_each             = local.ecr_repos
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = each.key
  }
}
