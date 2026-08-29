# Delta for infra-academy-estate-sg (bastion SSH)

## MODIFIED Requirements

### Requirement: East-west contract
In addition to the existing ALB / RDS / Bolt pairings, Terraform SHALL encode:

- `sg-portal`, `sg-rest`, `sg-haystack`, `sg-neo4j` ingress TCP 22 from `sg-bastion` only
- `sg-bastion` egress TCP 22 to those four SGs
- `sg-bastion` ingress TCP 22 only from `var.bastion_ssh_cidrs` (never `0.0.0.0/0`)

#### Scenario: App guests are not internet-SSH
- GIVEN the estate is applied
- WHEN app security-group ingress is listed
- THEN TCP 22 from `sg-bastion` is present
- AND TCP 22 from `0.0.0.0/0` is absent
