# Delta for infra-academy-estate-secrets-shells (bastion PEM)

## MODIFIED Requirements

### Requirement: Required secret ids exist
Terraform SHALL also create `heavy-rental/ssh/bastion` with `recovery_window_in_days = 0`. Values still wait for `sync-ssh-keys`.

#### Scenario: Bastion SSH shell exists empty
- GIVEN `action=apply` succeeded
- WHEN `describe-secret` is called for `heavy-rental/ssh/bastion`
- THEN the secret exists
- AND Terraform did not write `private_key_pem`
