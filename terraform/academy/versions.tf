terraform {
  required_version = ">= 1.15.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket name is account-specific; workflow passes -backend-config=bucket=...
  # Terraform 1.15: S3 native lock (use_lockfile). dynamodb_table is deprecated.
  backend "s3" {
    key          = "estate/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "heavy-rental"
      Environment = "academy"
      Lab         = "aws-academy-vocareum"
      Stack       = "estate"
    }
  }
}
