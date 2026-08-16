terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket name is account-specific; workflow passes -backend-config=bucket=...
  backend "s3" {
    key            = "estate/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "heavy-rental-tfstate-lock-academy"
    encrypt        = true
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
