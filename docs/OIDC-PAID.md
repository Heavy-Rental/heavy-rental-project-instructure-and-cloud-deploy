# Paid OIDC: AWS role → GitHub Environment `AWS_ACTUAL`

Do this **once** in the billed AWS account, then on this GitHub repo, **before** the first **AWS infrastructure (paid)** `plan`. Estate `apply` cannot create the IAM role it assumes.

You do **not** paste AWS access keys. GitHub Actions mints a short-lived OIDC token (`id-token: write`). AWS trusts that token and lets the runner assume your role.

What you copy from AWS into GitHub is the **role ARN** (`arn:aws:iam::123456789012:role/github-actions-infra`).

## 1. Create the OIDC provider and role in AWS

### Option A — script (recommended)

From a shell that already has **admin** AWS credentials (CloudShell, or `aws configure` on your laptop):

```bash
cd heavy-rental-project-instructure-and-cloud-deploy
GITHUB_ORG=YOUR_GITHUB_ORG ./scripts/bootstrap-github-oidc-paid.sh
```

Use the GitHub **org or user** that owns this repo (the part before `/heavy-rental-project-instructure-and-cloud-deploy`). The script:

1. Creates the IAM OIDC provider `token.actions.githubusercontent.com` if missing
2. Creates or updates role `github-actions-infra` trusted for `repo:YOUR_GITHUB_ORG/heavy-rental-project-instructure-and-cloud-deploy:*`
3. Attaches **AdministratorAccess** to that **runner** role so first `terraform apply` is not `AccessDenied`
4. Prints the role ARN

EC2 guests do **not** use this role. Terraform later creates `hr-paid-{portal,rest,haystack,neo4j,bastion}` for them.

### Option B — AWS Console

1. **IAM → Identity providers → Add provider**
   - Provider type: **OpenID Connect**
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - Add provider
2. **IAM → Roles → Create role**
   - Trusted entity: **Web identity**
   - Identity provider: `token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - Add condition (optional now; edit trust after create):
     - Key `token.actions.githubusercontent.com:sub`
     - Operator **StringLike**
     - Value `repo:YOUR_GITHUB_ORG/heavy-rental-project-instructure-and-cloud-deploy:*`
   - Permission policy: **AdministratorAccess** (runner only, first apply)
   - Role name: `github-actions-infra`
3. Open the role → copy **ARN**

Trust document (replace `ACCOUNT_ID` and `YOUR_GITHUB_ORG`): see [`samples/github-oidc-paid.json`](samples/github-oidc-paid.json).

## 2. Put the ARN on GitHub Environment `AWS_ACTUAL`

GitHub **cannot** create Environments from git.

1. This repo → **Settings → Environments → New environment**
2. Name it exactly **`AWS_ACTUAL`** (S3 state suffix is lowercase `actual`; do not name the Environment `paid`)
3. Store the role ARN **one** of these ways (both work):

| Where | Name | Value |
| --- | --- | --- |
| Environment **variable** (recommended) | `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::ACCOUNT_ID:role/github-actions-infra` |
| Environment **secret** | `AWS_ROLE_TO_ASSUME` | same ARN, if you want it hidden in the UI |

Do **not** use repository-wide secrets for this. Use the **Environment** so academy Vocareum keys cannot mix with paid.

4. Environment **variable** `AWS_REGION` = `us-east-1`. Optional (same names as academy, this Environment’s copies): `ALARM_EMAIL`, `BASTION_SSH_CIDRS` (your public IPv4 `/32`, comma-separated; empty = SSM onto `hr-bastion`; **not** `0.0.0.0/0`).
5. Environment **secrets** (app data only — same names as academy):

   - `SPRING_DATASOURCE_PASSWORD` (≥ 8) — required for `apply`
   - `NEO4J_PASSWORD`
   - `STRIPE_PUBLISHABLE_KEY`, `STRIPE_API_KEY` (`sk_…`), `STRIPE_WEBHOOK_SECRET`
   - Optional: `APP_JWT_SECRET`, `ONEMAP_EMAIL` + `ONEMAP_PASSWORD`, `LLM_API_KEY`

6. **Do not** add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or `AWS_SESSION_TOKEN`. The paid Action **fails** if `AWS_ACCESS_KEY_ID` is set.

Optional image **variables** on this Environment (for a later `deploy-projects`): `PORTAL_IMAGE`, `REST_IMAGE`, `HAYSTACK_IMAGE`. Not required for `apply`.

## 3. First paid run

1. **Actions → AWS infrastructure (paid) → Run workflow**
2. `aws_environment` = **`AWS_ACTUAL`**
3. `action` = **`plan`** first (proves OIDC + shows the estate)
4. Then `action` = **`apply`** (20–40 minutes: two Multi-AZ RDS, NAT, ALBs)

Success: job summary prints caller ARN, state `s3://heavy-rental-tfstate-<account>-actual/estate/terraform.tfstate`, public portal ALB, public REST ALB `:8080`, and `hr-paid-*`.

Portal / REST / Haystack **images** are a later `deploy-projects`, not part of `apply`. Day-to-day rolls after that are app CD paid callers in `heavy-rental-project-pipeline-development`.

## If assert fails

| Error | Fix |
| --- | --- |
| `AWS_ROLE_TO_ASSUME` empty | Add the role ARN as Environment variable **or** secret `AWS_ROLE_TO_ASSUME` on **`AWS_ACTUAL`** |
| `must not contain AWS_ACCESS_KEY_ID` | Delete that secret from Environment `AWS_ACTUAL` |
| `sts failed` / `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust `sub` must include this repo (`repo:ORG/heavy-rental-project-instructure-and-cloud-deploy:*`). Audience `sts.amazonaws.com`. |
| `AccessDenied` on CreateVPC / S3 | Runner role needs AdministratorAccess (or the sample `runner_policy`) |
| Environment is not `AWS_ACTUAL` | This Action refuses `academy`. Use workflow **AWS infrastructure (paid)** |

## Related

- Sample trust + policy: [`samples/github-oidc-paid.json`](samples/github-oidc-paid.json)
- Operator walkthrough: [`../OPERATOR-GUIDE.md`](../OPERATOR-GUIDE.md)
- Paid pipeline spec: [`../specification/pipelines/infra-paid.md`](../specification/pipelines/infra-paid.md)
- ADR [0017](adr/0017-two-actions-academy-paid.md), [0019](adr/0019-separate-job-graphs.md), [0021](adr/0021-maintenance-bastion-ssh.md) (`hr-paid-bastion`)
