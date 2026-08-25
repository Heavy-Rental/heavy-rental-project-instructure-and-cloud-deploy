data "aws_availability_zones" "available" {
  state = "available"
}

# Vocareum only. Paid must not look up LabRole (it will not exist).
data "aws_iam_role" "lab" {
  count = var.deployment == "academy" ? 1 : 0
  name  = var.lab_role_name
}

data "aws_iam_instance_profile" "lab" {
  count = var.deployment == "academy" ? 1 : 0
  name  = var.lab_instance_profile_name

  lifecycle {
    postcondition {
      condition     = self.role_name == data.aws_iam_role.lab[0].name
      error_message = "LabInstanceProfile must use IAM role LabRole. Vocareum pre-creates this pairing; do not create IAM."
    }
  }
}

# DescribeImages is on the Vocareum allow-list. Public SSM parameter
# /aws/service/ami-amazon-linux-latest/... is often AccessDenied.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Vocareum Learner Lab (run 2026-08-16) advertised only 11.22* and 12.22*.
# A list that stops at 14 matches nothing and plan dies in the data source.
# Prefer the clean community versions (not 11.22-rds.YYYYMMDD).
data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  preferred_versions = [
    "16", "15", "14", "13",
    "12.22", "12",
    "11.22", "11",
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

  ami_id = data.aws_ami.al2023.id
  # AL2023 snapshot on this lab is 30 GiB. Smaller root volumes fail ASG create.
  root_volume_gb = 30

  # Keep portal / REST / Haystack / Neo4j one guest per AZ.
  asg_az_distribution = "balanced-best-effort"

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

  observe_bucket = "heavy-rental-observe-${data.aws_caller_identity.current.account_id}-${var.deployment}"
  # Academy keeps historical names so apply does not replace the trail.
  observe_name = var.deployment == "academy" ? "heavy-rental-academy" : "heavy-rental-actual"

  is_academy = var.deployment == "academy"
  is_actual  = var.deployment == "actual"

  guest_apps = toset(["portal", "rest", "haystack", "neo4j"])

  asg_group_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMinSize",
    "GroupMaxSize",
  ]

  log_group_apps = toset(["portal", "rest", "haystack", "neo4j"])
}
