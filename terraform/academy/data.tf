data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_instance_profile" "lab" {
  name = var.lab_instance_profile_name
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Academy labs do not always offer Postgres 16. Prefer 16, then 15, then 14.
data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  preferred_versions = [
    "16.8", "16.6", "16.4", "16",
    "15.12", "15.10", "15.8", "15",
    "14.17", "14.15", "14",
  ]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  vpc_cidr     = "10.0.0.0/16"
  public_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  app_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  data_cidrs   = ["10.0.20.0/24", "10.0.21.0/24"]

  ami_id = data.aws_ssm_parameter.al2023.value

  secret_ids = toset([
    "heavy-rental/portal",
    "heavy-rental/rest",
    "heavy-rental/haystack",
    "heavy-rental/neo4j",
    "heavy-rental/ssh/portal",
    "heavy-rental/ssh/rest",
    "heavy-rental/ssh/haystack",
    "heavy-rental/ssh/neo4j",
  ])

  ecr_repos = toset([
    "heavy-rental-web-portal",
    "heavy-rental-rest-api",
    "heavy-rental-haystack",
    "heavy-rental-neo4j",
  ])
}
