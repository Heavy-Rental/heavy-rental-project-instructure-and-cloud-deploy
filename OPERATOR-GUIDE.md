# Operator guide — set up AWS and deploy the projects

This is a beginner walkthrough for the GitHub Action **AWS infrastructure (Academy)** in this repo.

You will:

1. Create the AWS lab estate (`apply`)
2. Deploy the portal, REST API, and Haystack onto that estate (`deploy-projects`)
3. Pause or wipe the lab when you are done (`stop` / `destroy`)

This workflow is **AWS Academy / Vocareum only**. Do not point it at a paid AWS account.

Related reference (more compact): [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md). Specs: [`specification/pipelines/infra-academy.md`](specification/pipelines/infra-academy.md).

---

## How the pieces fit

| Tool | What it does | What it does not do |
| --- | --- | --- |
| **Terraform** | Creates AWS *architecture*: VPC, NAT Gateways, 8 EC2 in four Auto Scaling groups, load balancers, two RDS databases, empty Secrets Manager shells | Does not install Docker or start your apps |
| **Ansible** | Configures *existing* EC2: Docker, `.env` from Secrets Manager, compose | Does not create VPCs, ASGs, or RDS |
| **This GitHub Action** | Runs Terraform and/or Ansible for you over SSM | Does not rebuild portal / REST / Haystack from source |

**Important:** `apply` does **not** start the three apps. After apply, the public portal URL returns **502** until you run **`deploy-projects`** in a **new** workflow run.

```
First lab day
  bootstrap   (once — state bucket)
       │
       ▼
     plan     (optional — preview only)
       │
       ▼
     apply    (create estate + Docker + Neo4j)
       │
       ▼
  Set image variables on Environment academy
       │
       ▼
 deploy-projects   ← new Run workflow, not the same run as apply
       │
       ▼
    Apps up (or 502 is gone on the portal ALB)
```

Later the same day, after you **Start Lab** again: `configure-only` (refresh guests), then `deploy-projects` only if you need to compose the apps again.

---

## One-time GitHub setup

Do this once on **this** repository (the infra repo), not on the portal / REST / Haystack app repos.

### 1. Create Environment `academy`

1. GitHub → this repo → **Settings** → **Environments** → **New environment**
2. Name it exactly `academy`
3. GitHub cannot create this from git. Do not use an Environment named `paid`.

### 2. Add secrets (Settings → Environments → academy → Environment secrets)

These are **not** typed on the Run form.

| Secret | Required for | Notes |
| --- | --- | --- |
| `SPRING_DATASOURCE_PASSWORD` | `apply`, `configure-only`, `deploy-projects` | At least 8 characters. RDS master password |
| `NEO4J_PASSWORD` | same | Neo4j admin password |
| `STRIPE_PUBLISHABLE_KEY` | same | `pk_…` |
| `STRIPE_API_KEY` | same | `sk_…` — never put this on the portal |
| `STRIPE_WEBHOOK_SECRET` | same | Webhook signing secret |
| `AWS_ACCESS_KEY_ID` | optional fallback | Only if you do not paste Vocareum keys on the form |
| `AWS_SECRET_ACCESS_KEY` | optional fallback | Same |
| `AWS_SESSION_TOKEN` | optional fallback | Same |

Do **not** add `VITE_STRIPE_PUBLISHABLE_KEY` (the pipeline copies it from the publishable key).

### 3. Add variables (Environment **variables**, not secrets)

| Variable | Value | When you need it |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | Always |
| `PORTAL_IMAGE` | Public GHCR or ECR tag | **Required** before `deploy-projects` |
| `REST_IMAGE` | Public GHCR or ECR tag | **Required** before `deploy-projects` |
| `HAYSTACK_IMAGE` | Public GHCR or ECR tag | **Required** before `deploy-projects` |

You can add the three image variables after `apply` succeeds. `apply` does not read them for compose.

**Images must be publicly pullable** (or already in this lab’s ECR). Private GitHub packages fail on purpose — the EC2 guests have no GitHub token.

Leave `IMAGE_HTTP_URL` unset for `deploy-projects`. One image tar cannot satisfy three apps.

These names on the **infra** Environment `academy` are separate from the same names on the three application repos.

---

## Every lab session

Vocareum AWS keys **expire when the lab session ends**. Start Lab again before you run the Action.

1. In Instructure / Vocareum, click **Start Lab**.
2. Open **AWS Details**.
3. Copy the three values: Access Key, Secret Key, Session Token.
4. In this GitHub repo: **Actions** → workflow **AWS infrastructure (Academy)** → **Run workflow**.
5. Fill the form (next section) and run.

Expect **20–40 minutes** for `apply` (two Multi-AZ RDS plus NAT and ALBs). That spends lab credits. Start the run at the **beginning** of a lab session — if Vocareum cancels the session mid-apply, state may not save.

**Ending the Vocareum session does not stop AWS billing.** NAT Gateways and ALBs keep billing until you run `destroy`.

---

## How to fill the Run workflow form

Every run uses the same form. Only some fields matter for each action.

| Field | What to choose | Notes |
| --- | --- | --- |
| **Use workflow from** | The branch that has this pipeline (usually your infra branch) | |
| **action** | See [each action](#each-action) below | Required |
| **aws_environment** | `academy` | Always. Any other name is refused |
| **confirm_destroy** | `no` unless you mean to wipe the estate | For `destroy` you must also pick `destroy` here |
| **aws_access_key_id** | Vocareum Access Key | Or leave empty if Environment secrets are set |
| **aws_secret_access_key** | Vocareum Secret Key | Same |
| **aws_session_token** | Vocareum Session Token | Same |
| **image_ref** | Usually empty | Optional fallback tag for REST and Haystack only. Does **not** set the portal |
| **image_http_url** | Leave empty | `deploy-projects` **fails** if this is set |

Job logs mask the three keys. The run **Inputs** page may still show them. Treat that page as sensitive.

---

## Recommended first-time path

Run these as **separate** workflow runs, in order.

| Step | `action` | Why |
| --- | --- | --- |
| 1 (once) | `bootstrap` | Creates the S3 bucket that stores Terraform state |
| 2 (optional) | `plan` | Shows what `apply` would create. Safe. No guests, no apps |
| 3 | `apply` | Creates the estate and installs Docker + Neo4j. Portal URL is **502** |
| 4 | *(no run)* | Set `PORTAL_IMAGE`, `REST_IMAGE`, `HAYSTACK_IMAGE` on Environment `academy` |
| 5 | `deploy-projects` | **New run.** Pulls the three images and starts the apps |

Do not try to do step 3 and step 5 in one click. `deploy-projects` is not chained onto `apply`.

---

## Each action

### `bootstrap` — create the state bucket (once)

**When:** The first time this lab account needs remote Terraform state. Skip it if a previous `bootstrap` or `apply` already created the bucket.

**What it does:** Creates an S3 bucket (with a lockfile) **outside** the estate. Does not create VPC, EC2, or RDS.

**Form:**

- `action` = `bootstrap`
- `aws_environment` = `academy`
- `confirm_destroy` = `no`
- Paste the three Vocareum keys

**Success:** Job is green. Later `plan` / `apply` can `terraform init` against that bucket.

**Do not:** Run this expecting apps or EC2. Nothing is deployed.

---

### `plan` — preview the estate (safe)

**When:** You want to see what Terraform would create or change **without** spending the full apply.

**What it does:** Checks the Vocareum session, ensures the state bucket exists, runs `terraform plan`. No `terraform apply`. No Ansible. Works even if `SPRING_DATASOURCE_PASSWORD` is missing (uses a plan-only placeholder that is never applied).

**Form:**

- `action` = `plan`
- `aws_environment` = `academy`
- `confirm_destroy` = `no`
- Paste the three Vocareum keys

**Success:** Job summary shows the plan. No new EC2.

**Do not:** Treat a green `plan` as “the lab is up.” You still need `apply`.

---

### `apply` — create the AWS estate

**When:** The lab has no estate yet, or you need Terraform to create/update resources.

**What it does:**

1. Confirms Environment `academy` and Vocareum keys
2. `terraform apply` — VPC, two NAT Gateways, four ASGs (**8 EC2**), ALBs, two RDS, secret *shells*
3. Writes app secrets into Secrets Manager (`sync-secrets`)
4. Writes break-glass SSH PEMs after instances are healthy (`sync-ssh-keys`)
5. Ansible `configure.yml` — Docker + Compose on all guests, **Neo4j only**

It does **not** pull portal, REST, or Haystack images. That is why apply no longer fails on private GHCR.

**Form:**

- `action` = `apply`
- `aws_environment` = `academy`
- `confirm_destroy` = `no`
- Paste the three Vocareum keys
- Leave `image_ref` and `image_http_url` empty

**Success (about 20–40 minutes):**

- Four ASGs exist: `asg-portal`, `asg-rest`, `asg-haystack`, `asg-neo4j`
- Job summary shows the public portal ALB DNS
- That URL **502**s on port 80 until `deploy-projects` (or portal app CD)
- Secret `heavy-rental/portal` exists and has `REST_BASE_URL`

**Common problems:**

| Symptom | What to do |
| --- | --- |
| Missing `SPRING_DATASOURCE_PASSWORD` / Stripe / Neo4j password | Add them on Environment `academy`, re-run |
| `device index 0 … cannot be detached` | See [Apply fails: primary ENI](#apply-fails-device-index-0--cannot-be-detached) |
| `voc-cancel-cred` / `Failed to persist state to backend` | See [Apply fails: Vocareum cancelled credentials](#apply-fails-vocareum-cancelled-credentials-voc-cancel-cred) |
| You expected the React portal to load | Run `deploy-projects` next. Apply is not a full deploy |

**Billing:** NAT Gateways and ALBs start billing now. They keep billing after `stop` and after the Vocareum session ends, until `destroy`.

---

### `configure-only` — refresh guests, no Terraform

**When:** The estate already exists (you already ran `apply`), the Vocareum session is new, and you need Docker / secrets / Neo4j refreshed. Typical: next lab session the same week.

**What it does:** Same Ansible as apply (`configure.yml`): refill Secrets Manager, PEMs, Docker + Compose on all guests, compose **Neo4j only**. **No** `terraform apply`. **No** portal / REST / Haystack compose.

**Form:** Same as `apply`, but `action` = `configure-only`.

**Success:** Docker is on the guests. Neo4j is up. Apps are still whatever they were (or still absent).

**Do not:** Use this as the first action on an empty account — there are no ASGs yet. Run `apply` first.

---

### `deploy-projects` — start portal, REST, and Haystack

**When:** A **later** run, after a **successful** `apply` or `configure-only` in this lab. This is the action that deploys the three projects onto the EC2 guests.

**What it does:**

1. Refreshes secrets and PEMs (same as configure-only)
2. **Preflight on the runner** (fails *before* talking to EC2 if something is wrong):
   - All four ASGs exist (otherwise: run `apply` first)
   - `PORTAL_IMAGE` is set and is **not** stock `nginx`
   - `REST_IMAGE` and `HAYSTACK_IMAGE` are set (or `image_ref` for those two)
   - Each `ghcr.io/…` tag is **publicly** readable
   - `image_http_url` / `IMAGE_HTTP_URL` are empty
3. Ansible `site.yml` — compose portal + REST + Haystack + Neo4j, and `CREATE EXTENSION vector` on Haystack RDS

**Form:**

- `action` = `deploy-projects`
- `aws_environment` = `academy`
- `confirm_destroy` = `no`
- Paste the three Vocareum keys
- Leave `image_http_url` **empty**
- Leave `image_ref` empty unless you are using it as the REST/Haystack fallback

**Success:**

- Portal ALB answers on `/` (no longer 502)
- REST answers on the internal REST ALB / guest `:8080`
- Haystack answers on `:8000`

**Common problems:**

| Symptom | Cause |
| --- | --- |
| “run `apply` first” | ASGs missing. This action is not Terraform |
| Stock nginx / empty `PORTAL_IMAGE` | Set a real portal CI tag on Environment `academy` |
| Empty REST / Haystack | Set `REST_IMAGE` and `HAYSTACK_IMAGE` |
| Private GHCR (401/403) | Make the package public, or copy the image to ECR. Do not put a GitHub PAT on the guest |
| `image_http_url` refused | One tar cannot deploy three images. Use registry tags |

**Do not:**

- Run this in the **same** workflow run as `apply` (the form only allows one `action`)
- Use this every time you change one app — after first compose, prefer that app’s own CD
- Re-run it after app CD unless you intend to **reset all three** apps to the infra Environment tags

---

### `stop` — pause compute (still bills NAT)

**When:** End of a lab day when you will come back, and you want EC2 and RDS stopped. Cheaper than leaving 8 instances running, **but not free**.

**What it does:** Sets all four ASGs to desired = 0. Stops both RDS instances. Does **not** destroy NAT Gateways or ALBs. Those **keep billing**.

**Form:**

- `action` = `stop`
- `confirm_destroy` = `no`
- Paste the three Vocareum keys

**Success:** ASGs show desired 0. RDS status is stopped.

**To resume:** Start Lab, then `configure-only` (ASGs scale back as designed). Run `deploy-projects` again if the apps are gone after new instances launch.

---

### `destroy` — wipe the estate

**When:** You are finished with the lab or apply is half-broken and you want a clean slate. This is the only action that **stops NAT Gateway billing**.

**What it does:** Terminates estate EC2 first, then `terraform destroy`. **Keeps** the S3 state bucket (so the next `apply` can run).

**Form (both required):**

- `action` = `destroy`
- **`confirm_destroy` = `destroy`**
- `aws_environment` = `academy`
- Paste the three Vocareum keys

If you leave `confirm_destroy` = `no`, destroy does **not** run. That is intentional.

**Success:** Estate resources are gone. State bucket remains. Next time: `apply`, then `deploy-projects`.

**Do not:** Use `stop` when you meant “stop all charges.” Use `destroy`.

---

## Apply fails: `device index 0 … cannot be detached`

AWS will not detach an instance’s **primary** network interface (eth0). This usually means Terraform is trying to destroy a leftover Neo4j ENI while a guest still owns eth0.

1. AWS Console → EC2 → Network Interfaces → the `eni-…` in the error. Note the attached instance name.
2. **Terminate** that instance (the ASG launches a replacement without that extra ENI). That releases eth0.
3. If Terraform state still lists `aws_network_interface*` / `aws_network_interface_attachment*`, remove that address from state (`terraform state rm`). Do not `destroy` it while the guest is running.
4. Re-run **`apply`**. Do not attach a dedicated ENI to Neo4j.

To wipe a half-applied estate instead: `destroy` (with `confirm_destroy=destroy`), then `apply`.

---

## Apply fails: Vocareum cancelled credentials (`voc-cancel-cred`)

Terraform created something in AWS (often RDS after ~15 minutes), then could not write `estate/terraform.tfstate` to S3. The deny is **not** a missing bucket policy. Vocareum attached identity policy `voc-cancel-cred` because the lab session ended, **End Lab** was clicked, credits ran out, or the Environment `AWS_*` secrets are from a previous Start Lab.

The GitHub runner’s `errored.tfstate` is **gone** when the job ends. Do **not** re-run `apply` until you reconcile. A second apply can fork state or hit `DBInstanceAlreadyExists`.

1. **Start Lab** again and paste **new** AWS Details on the Run form.
2. Check Actions: no other infra run is still in the Terraform job.
3. List the lock: `aws s3 ls s3://heavy-rental-tfstate-<account>-academy/estate/`. If `terraform.tfstate.tflock` is present, `terraform force-unlock <LOCK_ID>` from `terraform/academy` after `init`. Only if nobody else holds the lock.
4. Compare AWS to state:
   - `aws rds describe-db-instances` for `heavy-rental-academy` and `heavy-rental-haystack-academy`
   - `terraform state list | grep aws_db_instance`
5. **Keep the estate:** `terraform import aws_db_instance.heavy_rental heavy-rental-academy` (and `aws_db_instance.haystack` / `heavy-rental-haystack-academy` if that instance exists and is missing from state). Import any other `AlreadyExists` address `plan` reports. Run `action=plan`. Only `apply` when the plan is not “create RDS again.”
6. **Or wipe:** `action=destroy` with `confirm_destroy=destroy`. Delete any RDS destroy cannot see (never written to state). Then `apply` at the **start** of a new lab session.

NAT Gateways and ALBs that already exist **keep billing** after the session ends, until `destroy`.

---

## After the apps are up

| You want to… | Use |
| --- | --- |
| Change only the portal image | Portal app CD in `heavy-rental-web-portal-pipeline` |
| Change only REST | REST app CD in `heavy-rental-rest-api` |
| Change only Haystack | Haystack app CD in `haystack-fast-api-pipeline` |
| Re-compose all three from infra tags | `deploy-projects` again (resets all three) |
| Pause overnight | `stop` (NAT still bills) |
| Stop NAT/ALB charges | `destroy` |

App CD workflows must **not** run Terraform. This repo owns the estate.

---

## What this workflow must never do

- Create IAM roles or OIDC (guests use Vocareum `LabRole` / `LabInstanceProfile`)
- Write Vocareum `AWS_*` keys into Secrets Manager or onto EC2
- Put `SPRING_DATASOURCE_PASSWORD` on the Run form
- Put a GitHub PAT on the guests to pull private GHCR
- Target a paid AWS account
