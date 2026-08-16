# SPDD Analysis: add-infra-academy-bootstrap

**Status:** Active  
**Audience:** Implementers of the Academy / Vocareum infra CD bootstrap  
**Companion:** [REASONS Canvas](../prompt/add-infra-academy-bootstrap.md) · [OpenSpec change](../../openspec/changes/add-infra-academy-bootstrap/proposal.md)

## Problem

The cloud-deploy repo is a blank template. Vocareum sessions die and mint new AWS keys every Start Lab. A GitHub Actions runner discards local `terraform.tfstate`. The class cannot `terraform plan` until (1) the runner can assume the Vocareum caller and (2) a remote backend exists that is **not** the estate it will later store.

Creating the VPC in the same change hides a dead lab session behind a large apply.

## Concepts

| Concept | Meaning here |
| --- | --- |
| Academy / Vocareum | Instructure Learner Lab; federated `voclabs/…`; no new IAM roles |
| Form keys | `workflow_dispatch` inputs for the three AWS Details values |
| Environment `academy` | Fallback secrets + `AWS_REGION`; reviewers |
| Backend stack | S3 + DynamoDB lock; `terraform/backend/`; not the estate |
| Estate stack | `terraform/academy/`; placeholder on this branch |
| Paid | Billed account + OIDC; **another** workflow; not this change |

## Stakeholders

- Class operators (Start Lab, paste keys, run `plan`)
- Pipeline authors (must not invent paid/OIDC here)
- Later estate / Ansible / app-CD branches (consume this backend)

## Risks

1. **Keys on paid** — Vocareum form fields must never appear on `aws-infra-paid.yml`.
2. **Keys in SM or on EC2** — session tokens expire; LabRole is the guest identity.
3. **VPC on branch 1** — spend credits before auth is proven.
4. **Backend in estate state** — chicken-and-egg; destroy would delete its own bucket.
5. **Semgrep injection** — bind `github.*` / `inputs.*` through `env:` in `run:` scripts.

## Strategy

1. Specify behavior in OpenSpec (`infra-academy-auth|backend|plan|scope`).
2. Bind implementation in this analysis + REASONS Canvas.
3. Implement YAML + two tiny Terraform roots already on this branch.
4. Fail `apply` / configure / stop / destroy until later branches.

## Success

- `action=plan` after Start Lab is green.
- No `aws_vpc` / ALB / RDS / ASG in `terraform/academy/`.
- Only workflow is `aws-infra-academy.yml`.
- Backend bucket name includes the Vocareum account id and the suffix `-academy`.
