# Academy / Vocareum bootstrap (branch 1)

This repo’s first pipeline is **AWS Academy Learner Lab (Vocareum) only**. There is no paid / OIDC workflow on this branch.

## One-time GitHub setup

1. Repo **Settings → Environments → New environment** named **`academy`**.
2. Optional fallback secrets (if you do not want to paste keys every run):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
3. Variable: `AWS_REGION` = `us-east-1`.
4. GitHub cannot create this Environment from git. Paid Environment must **not** exist on this workflow.

## Every lab session

Vocareum tokens **expire when the session ends**.

1. Instructure → **Start Lab** → AWS Details.
2. Actions → **AWS infrastructure (Academy)** → Run workflow.
3. Paste `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token` (or leave empty to use Environment secrets).
4. Set `aws_environment` = `academy`.
5. Choose `action` = **`plan`**.

First `plan` creates the **state bucket + lock table** if they are missing, then `terraform plan` on an empty estate. **No VPC, ALB, or RDS.**

## Actions

| `action` | Branch 1 behaviour |
| --- | --- |
| `plan` | assert-lab → ensure backend → `terraform plan` (placeholder) |
| `bootstrap` | assert-lab → ensure backend only |
| `apply` | **Fails** — estate is branch 2 |
| `configure-only` / `stop` / `destroy` | **Fails** — not in branch 1 |

## What this must not do

- Create IAM roles or an OIDC provider
- Create a NAT Gateway or Marketplace Neo4j
- Write Vocareum keys into Secrets Manager or onto EC2
- Target a billed / paid account
