terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local state only for this one-shot stack. After apply, the workflow
# copies terraform.tfstate into the new bucket at backend/terraform.tfstate.
# This stack is NOT the academy estate state.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "heavy-rental"
      Environment = "academy"
      Lab         = "aws-academy-vocareum"
      Stack       = "tfstate-backend"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "Vocareum labs are us-east-1 (vockey lives there)."
  default     = "us-east-1"
}
