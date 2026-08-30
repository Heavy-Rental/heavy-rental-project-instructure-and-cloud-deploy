# REASONS Canvas: add-infra-bastion

Create `hr-bastion` as a single public-subnet EC2 (not an ASG) as the maintenance SSH jump. App SGs allow `:22` only from `sg-bastion`. `sync-ssh-keys` writes `private_key_pem` (the **private** key) and `public_key` to `heavy-rental/ssh/*`, installs **public** keys on guests, and puts hop + role **private** keys on the bastion (`id_ed25519`, `id_portal`, …). Optional `BASTION_SSH_CIDRS`; SSM if empty. Ansible does not compose onto `bastion`. `stop` uses `stop-instances`.

**Do not:** `:22` from `0.0.0.0/0`; **private** keys on app guests; Docker on bastion; max>1; Terraform `tls_private_key`. Treat `private_key_pem` as the private key, not the `.pub` line.
