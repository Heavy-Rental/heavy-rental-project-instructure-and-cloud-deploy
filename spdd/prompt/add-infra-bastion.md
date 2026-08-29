# REASONS Canvas: add-infra-bastion

Create `hr-bastion` as a single public-subnet EC2 (not an ASG) as the maintenance SSH jump. App SGs allow `:22` only from `sg-bastion`. `sync-ssh-keys` installs the bastion public key on all guests and the private hop key only on the bastion. Optional `BASTION_SSH_CIDRS`; SSM if empty. Ansible does not compose onto `bastion`. `stop` uses `stop-instances`.

**Do not:** `:22` from `0.0.0.0/0`; PEM on app guests; Docker on bastion; max>1; Terraform `tls_private_key`.
