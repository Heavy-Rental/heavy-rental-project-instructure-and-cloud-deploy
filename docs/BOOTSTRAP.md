# Academy / Vocareum estate (branch 3 configure)

This repo’s pipeline is **AWS Academy Learner Lab (Vocareum) only**. There is no paid / OIDC workflow on this branch.

## One-time GitHub setup

1. Repo **Settings → Environments → New environment** named **`academy`**.
2. Optional fallback AWS secrets (if you do not paste keys on the Run form):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
3. **Required for `action=apply`:** secret `SPRING_DATASOURCE_PASSWORD` (RDS master; later copied into `heavy-rental/rest` by branch 3). **Not** a workflow input.
4. Variable: `AWS_REGION` = `us-east-1`.
5. Optional image variables (not secrets): `PORTAL_IMAGE` (nginx-based React CI tag; empty = stock `nginx`), `REST_IMAGE`, `HAYSTACK_IMAGE`, `IMAGE_HTTP_URL`.
6. GitHub cannot create this Environment from git. Do **not** point this workflow at a `paid` Environment.

## Every lab session

Vocareum tokens **expire when the session ends**.

1. Instructure → **Start Lab** → AWS Details.
2. Actions → **AWS infrastructure (Academy)** → Run workflow.
3. Paste `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token` (or leave empty to use Environment AWS secrets). Job logs mask these; the run Inputs page may still show them.
4. Set `aws_environment` = `academy`.
5. Choose `action`:
   - **`plan`** — show the estate (no apply). Works without `SPRING_DATASOURCE_PASSWORD` (uses a plan-only placeholder).
   - **`apply`** — create the estate, then `sync-secrets` → `sync-ssh-keys` → Ansible. Needs `SPRING_DATASOURCE_PASSWORD`, `NEO4J_PASSWORD`, Stripe trio. Portal uses Environment `PORTAL_IMAGE` or stock `nginx`. REST/Haystack need `REST_IMAGE` / `HAYSTACK_IMAGE` or `image_ref`. Guest count is **8 EC2**. NAT Gateways bill until `destroy`.
   - **`configure-only`** — no Terraform apply. Refill secrets, PEMs, compose (after Start Lab / image change).
   - **`stop`** — ASG desired=0 + stop both RDS. **NAT Gateways and ALBs still bill.**
   - **`destroy`** — wipe the estate. Set **both** `action=destroy` **and** `confirm_destroy=destroy`. Terminates EC2 first. **Keeps** the state bucket.
   - **`bootstrap`** — state bucket only (S3 native lockfile).

Expect **15–20 minutes** on apply (RDS + ALBs). This spends lab credits. **Ending the Vocareum session does not stop RDS or ALB billing.**

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
| Public portal ALB DNS (job summary) | Resolves; `:80` after configure (stock nginx until a portal CI image) |
| `describe-secret --secret-id heavy-rental/portal` | Has `REST_BASE_URL` after `sync-secrets` |
| `configure-only` | Fills SM + compose. Portal uses `PORTAL_IMAGE` or stock nginx. REST/Haystack need images. |
| `stop` | ASGs desired=0; both RDS stopped; Gateways still bill |

## Actions

| `action` | Branch 3 behaviour |
| --- | --- |
| `plan` | assert-lab → ensure backend → `terraform plan` (estate) |
| `bootstrap` | assert-lab → ensure backend only |
| `apply` | assert-lab → ensure backend → terraform apply → sync-secrets → sync-ssh-keys → Ansible |
| `destroy` | assert-lab → terminate estate EC2 → `terraform destroy` (needs `confirm_destroy=destroy`). Does **not** create a backend or run estate plan/apply. |
| `configure-only` | assert-lab → sync-secrets → sync-ssh-keys → Ansible (no terraform apply) |
| `stop` | assert-lab → ASG desired=0 + stop both RDS |

## What this must not do

- Create IAM roles or an OIDC provider (`LabInstanceProfile` only)
- Create a NAT **instance** or Marketplace Neo4j. Outbound is two NAT Gateways (ADR 0010).
- Write Vocareum keys into Secrets Manager or onto EC2
- Put `SPRING_DATASOURCE_PASSWORD` on the Run form
- Echo Vocareum keys in job logs (`env:` / `${{ inputs.aws_* }}`)
- Put `sk_` on the portal secret
- Target a billed / paid account
