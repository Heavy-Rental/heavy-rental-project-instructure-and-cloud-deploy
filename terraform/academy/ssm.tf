# Paid only. Ansible aws_ssm puts modules here; guests GetObject.
# Do not reuse the Terraform state bucket (guests must not write estate/terraform.tfstate).

resource "aws_s3_bucket" "ansible_ssm" {
  count         = local.is_actual ? 1 : 0
  bucket        = "heavy-rental-ssm-${data.aws_caller_identity.current.account_id}-${var.deployment}"
  force_destroy = true

  tags = {
    Name = "heavy-rental-ssm"
    Role = "ansible-ssm"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_ssm" {
  count                   = local.is_actual ? 1 : 0
  bucket                  = aws_s3_bucket.ansible_ssm[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_ssm" {
  count  = local.is_actual ? 1 : 0
  bucket = aws_s3_bucket.ansible_ssm[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ansible_ssm" {
  count  = local.is_actual ? 1 : 0
  bucket = aws_s3_bucket.ansible_ssm[0].id

  rule {
    id     = "expire-7d"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}
