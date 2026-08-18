# Academy / Vocareum estate (branch 3 configure)

This repo’s pipeline supports **two profiles** on the same Action: **`academy`** (Vocareum) and **`AWS_ACTUAL`** (public AWS via OIDC). They use different GitHub Environments and different Terraform state buckets.

**Terraform** creates the estate. **Ansible** only configures guests that already exist (Docker, `.env`, compose). It does not create VPCs or ASGs. Beginner walkthrough (every `action`): [`../OPERATOR-GUIDE.md`](../OPERATOR-GUIDE.md). Spec index: [`../specification/README.md`](../specification/README.md).

## One-time GitHub setup

1. Repo **Settings → Environments → New environment** named **`academy`**.
2. Optional fallback AWS secrets (if you do not paste keys on the Run form):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
3. **Required secrets for `apply` / `configure-only`:** `SPRING_DATASOURCE_PASSWORD` (≥ 8), `NEO4J_PASSWORD`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_API_KEY` (`sk_…`), `STRIPE_WEBHOOK_SECRET`. **Not** workflow inputs. Do not add `VITE_STRIPE_PUBLISHABLE_KEY` (copied from the publishable key). Optional: `APP_JWT_SECRET` (≥ 32 chars, HS256). If unset, `sync-secrets` reuses the value already in `heavy-rental/rest` or generates one. Set it if you need the same JWT secret after `destroy` + `apply`. Optional OneMap: `ONEMAP_EMAIL` and `ONEMAP_PASSWORD` (both or neither). `APP_CORS_ALLOWED_ORIGINS` is **not** a GitHub secret — `sync-secrets` sets it from the public portal ALB DNS. Optional pricing **variables** (not secrets): `DYNAMIC_PRICING_ENABLED`, `PRICING_DEFAULT_DISTANCE_KM`, `PRICING_ORIGIN_POSTAL_CODE`, `PRICING_DISTANCE_LOOKUP_ENABLED`. Empty = omit (Spring defaults). REST CD Environment `academy` can overlay the same names without a new infra run.
4. Variable: `AWS_REGION` = `us-east-1`. Optional: `ALARM_EMAIL` for CloudWatch SNS (confirm the AWS mail).
5. Image **variables** (not secrets) on this repo’s Environment `academy` — not the app-repo Environments: `PORTAL_IMAGE` (ECR or public GHCR tag; **required** for `deploy-projects`, stock `nginx` forbidden on that action), `REST_IMAGE`, `HAYSTACK_IMAGE`. Do **not** set `IMAGE_HTTP_URL` for `deploy-projects` (one tar cannot satisfy three images). `image_ref` on the Run form is REST/Haystack fallback only. `ansible/inventory/group_vars/all.yml` looks these up from the runner env. `apply` / `configure-only` still do **not** compose portal/REST/Haystack (`configure.yml`).
6. GitHub cannot create Environments from git. For public AWS: create Environment **`AWS_ACTUAL`**, set `AWS_ROLE_TO_ASSUME` (OIDC role ARN in the billed account), same app secrets as academy, **no** `AWS_ACCESS_KEY_ID`. See ADR 0016.

## Every lab session

Vocareum tokens **expire when the session ends**.

1. Instructure → **Start Lab** → AWS Details.
2. Actions → **AWS infrastructure (Academy)** → Run workflow.
3. Paste `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token` (or leave empty to use Environment AWS secrets). Job logs mask these; the run Inputs page may still show them.
4. Set `aws_environment` = `academy` (Vocareum) or `AWS_ACTUAL` (public AWS).
5. Choose `action`:
   - **`plan`** — import any named leftovers into state, then show the estate (no apply). Works without `SPRING_DATASOURCE_PASSWORD` (uses a plan-only placeholder).
   - **`apply`** — same import, then create or update the estate (Terraform), then `sync-secrets` → `sync-ssh-keys` → Ansible **`configure.yml`** (Docker + Compose on all guests; **Neo4j only**). Does **not** pull portal/REST/Haystack images. Needs `SPRING_DATASOURCE_PASSWORD`, `NEO4J_PASSWORD`, Stripe trio. Guest count is **8 EC2**. Also creates CloudTrail (S3 only), VPC flow logs, ALB access logs, CloudWatch alarms + dashboard `heavy-rental-academy`. Guests use **LabRole**. NAT Gateways bill until `destroy`. Safe to re-run after a failed apply.
   - **`configure-only`** — **no Terraform apply**. Same Ansible as apply: Docker + Compose on all guests; Neo4j compose only. Portal / REST / Haystack **images** are not pulled.
   - **`deploy-projects`** — **later run** after a successful `apply` or `configure-only` (new workflow run; not chained). Preflights public GHCR or ECR tags, then `site.yml` (portal + REST + Haystack + Neo4j + `rds_logical`). Needs `PORTAL_IMAGE` / `REST_IMAGE` / `HAYSTACK_IMAGE`. Day-to-day single-image rolls stay app CD.
   - **`stop`** — ASG desired=0 + stop both RDS. **NAT Gateways and ALBs still bill.**
   - **`destroy`** — wipe the estate. Set **both** `action=destroy` **and** `confirm_destroy=destroy`. Imports leftovers, terminates EC2, destroys state, then sweeps named orphans and extra estate VPCs. **Keeps** the state bucket.
   - **`bootstrap`** — state bucket only (S3 native lockfile).

Expect **20–40 minutes** on apply (two Multi-AZ RDS + ALBs). This spends lab credits. Start apply at the beginning of a lab session. **Ending the Vocareum session does not stop RDS or ALB billing.**

### Apply fails: `voc-cancel-cred` / failed to persist state

Vocareum cancelled the session (`policy/voc-cancel-cred`) after Terraform created resources (often the first Multi-AZ RDS). S3 `PutObject` on `estate/terraform.tfstate` is an explicit deny. The runner `errored.tfstate` is not kept.

1. Start Lab. Paste fresh AWS Details (do not reuse cancelled Environment `AWS_*` secrets).
2. Re-run **`action=apply`**. The job clears a leftover lock file and **imports** named leftovers before plan.
3. If reconcile reports two `heavy-rental-academy` VPCs: **`destroy`** then **`apply`**.

See [`../OPERATOR-GUIDE.md`](../OPERATOR-GUIDE.md) — *Apply fails: Vocareum cancelled credentials* and *named object already exists*.

### Apply fails: `device index 0 … cannot be detached`

AWS will not detach an instance’s **primary** ENI (eth0). Terraform is destroying a leftover dedicated Neo4j ENI or replacing the NAT while routes still pin that eth0.

1. Console → EC2 → Network Interfaces → the `eni-…` in the error. Note the attached instance Name (usually an ASG guest).
2. **Terminate** that instance (ASG relaunches without a dedicated ENI). That is what releases eth0.
3. If state still lists `aws_network_interface*` / `aws_network_interface_attachment*`, `terraform state rm` that address. Do not `destroy` it while the guest is running.
4. Re-run **apply**. Do not put a dedicated ENI back on Neo4j. There is no NAT instance.

To wipe the whole half-applied estate instead: `action=destroy` with `confirm_destroy=destroy`, then `action=apply`. Destroy terminates estate EC2 first so this detach error does not block teardown.

## After apply

| Check | Expect |
| --- | --- |
| `describe-auto-scaling-groups --auto-scaling-group-names asg-portal asg-rest asg-haystack asg-neo4j` | All four exist |
| Public portal ALB DNS (job summary) | Resolves; **502** on `:80` until `deploy-projects` or portal app CD |
| `describe-secret --secret-id heavy-rental/portal` | Has `REST_BASE_URL` after `sync-secrets` |
| `configure-only` | Fills SM + PEMs. Docker + Compose on all guests. Composes **Neo4j only**. |
| `deploy-projects` | After apply/configure-only. Composes portal + REST + Haystack. |
| `stop` | ASGs desired=0; both RDS stopped; Gateways still bill |

## Actions

| `action` | Branch 3 behaviour |
| --- | --- |
| `plan` | assert-lab → ensure backend → import leftovers → `terraform plan` (estate) |
| `bootstrap` | assert-lab → ensure backend only |
| `apply` | assert-lab → ensure backend → import leftovers → terraform apply → sync-secrets → sync-ssh-keys → Ansible `configure.yml` |
| `destroy` | assert-lab → import leftovers → terminate estate EC2 → `terraform destroy` → sweep orphans (needs `confirm_destroy=destroy`). Does **not** create a backend or run estate plan/apply. |
| `configure-only` | assert-lab → sync-secrets → sync-ssh-keys → Ansible `configure.yml` (Docker + Compose on all guests; Neo4j compose; no app images) |
| `deploy-projects` | assert-lab → sync-secrets → sync-ssh-keys → image preflight → Ansible `site.yml`. Separate run after apply or configure-only. |
| `stop` | assert-lab → ASG desired=0 + stop both RDS |

## What this must not do

- Create IAM roles or an OIDC provider (`LabInstanceProfile` only)
- Create a NAT **instance** or Marketplace Neo4j. Outbound is two NAT Gateways (ADR 0010).
- Write Vocareum keys into Secrets Manager or onto EC2
- Put `SPRING_DATASOURCE_PASSWORD` on the Run form
- Echo Vocareum keys in job logs (`env:` / `${{ inputs.aws_* }}`)
- Put `sk_` on the portal secret
- Create IAM (`aws_iam_role`) or attach LabRole to CloudTrail / flow-log delivery
- Enable CloudTrail → CloudWatch Logs or RDS enhanced monitoring
- Target a billed / paid account
