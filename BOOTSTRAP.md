# Academy / Vocareum estate (branch 2)

This repo’s pipeline is **AWS Academy Learner Lab (Vocareum) only**. There is no paid / OIDC workflow on this branch.

## One-time GitHub setup

1. Repo **Settings → Environments → New environment** named **`academy`**.
2. Optional fallback AWS secrets (if you do not paste keys on the Run form):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
3. **Required for `action=apply`:** secret `SPRING_DATASOURCE_PASSWORD` (RDS master; later copied into `heavy-rental/rest` by branch 3). **Not** a workflow input.
4. Variable: `AWS_REGION` = `us-east-1`.
5. GitHub cannot create this Environment from git. Do **not** point this workflow at a `paid` Environment.

## Every lab session

Vocareum tokens **expire when the session ends**.

1. Instructure → **Start Lab** → AWS Details.
2. Actions → **AWS infrastructure (Academy)** → Run workflow.
3. Paste `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token` (or leave empty to use Environment AWS secrets). Job logs mask these; the run Inputs page may still show them.
4. Set `aws_environment` = `academy`.
5. Choose `action`:
   - **`plan`** — show the estate (no apply). Works without `SPRING_DATASOURCE_PASSWORD` (uses a plan-only placeholder).
   - **`apply`** — create the VPC, four ASGs, three ALBs, two RDS (`heavy_rental` + `haystack`), SM shells, ECR. Needs `SPRING_DATASOURCE_PASSWORD`.
   - **`bootstrap`** — state bucket only (S3 native lockfile).

Expect **15–20 minutes** on apply (RDS + ALBs). This spends lab credits. **Ending the Vocareum session does not stop RDS or ALB billing.**

## After apply

| Check | Expect |
| --- | --- |
| `describe-auto-scaling-groups --auto-scaling-group-names asg-portal asg-rest asg-haystack asg-neo4j` | All four exist |
| Public portal ALB DNS (job summary) | Resolves; **may 502** (no nginx yet) |
| `describe-secret --secret-id heavy-rental/portal` | Shell exists; no `REST_BASE_URL` yet |
| `configure-only` / `stop` / `destroy` | **Fail** — branch 3 |

## Actions

| `action` | Branch 2 behaviour |
| --- | --- |
| `plan` | assert-lab → ensure backend → `terraform plan` (estate) |
| `bootstrap` | assert-lab → ensure backend only |
| `apply` | assert-lab → ensure backend → `init` + `plan` + `apply` |
| `configure-only` / `stop` / `destroy` | **Fails** — `feat/infra-academy-configure` |

## What this must not do

- Create IAM roles or an OIDC provider (`LabInstanceProfile` only)
- Create a NAT Gateway or Marketplace Neo4j
- Write Vocareum keys into Secrets Manager or onto EC2
- Put `SPRING_DATASOURCE_PASSWORD` on the Run form
- Echo Vocareum keys in job logs (`env:` / `${{ inputs.aws_* }}`)
- Fill secret JSON, install Docker, or compose (branch 3)
- Target a billed / paid account
