variable "deployment" {
  type        = string
  default     = "academy"
  description = "academy or actual. Suffix on the state bucket (lowercase; Environment AWS_ACTUAL maps to actual)."

  validation {
    condition     = contains(["academy", "actual"], var.deployment)
    error_message = "deployment must be academy or actual."
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "heavy-rental-tfstate-${local.account_id}-${var.deployment}"
}

# No aws_iam_role. Vocareum LabRole / federated user creates these.
# No VPC, NAT Gateway, or Marketplace resources.

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "estate_state_key" {
  value = "estate/terraform.tfstate"
}

output "vocareum_account_id" {
  value = local.account_id
}
