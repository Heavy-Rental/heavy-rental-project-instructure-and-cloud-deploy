# Branch 1 placeholder — feat/infra-academy-bootstrap
# No VPC, ALB, RDS, ASG, or Secrets Manager values.
# Branch 2 (feat/infra-academy-estate) replaces this with the three-tier estate.

resource "terraform_data" "academy_bootstrap_placeholder" {
  input = "vocareum-academy-estate-not-yet-created"
}

output "bootstrap_status" {
  value       = "academy-placeholder"
  description = "Branch 1: plan-only. Estate resources land in feat/infra-academy-estate."
}

output "lab" {
  value = "aws-academy-vocareum"
}
