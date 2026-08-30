# Delta for infra-academy-sync-ssh

> **Later modified by** [`add-infra-bastion`](../../../add-infra-bastion/specs/infra-academy-sync-ssh/spec.md) / [ADR 0021](../../../../../docs/adr/0021-maintenance-bastion-ssh.md): also `heavy-rental/ssh/bastion`; hop **private** key on `hr-bastion` plus copies of the four role **private** keys (`id_{portal,rest,haystack,neo4j}`) from SM `private_key_pem`. Host aliases. App guests still never receive a private key. `private_key_pem` is the private key, not the public `.pub`.

## Purpose

Break-glass PEMs exist only after ASG guests are InService. Everyday operate is SSM.

## ADDED Requirements

### Requirement: PEMs after InService
`sync-ssh-keys` SHALL wait until each of `asg-portal`, `asg-rest`, `asg-haystack`, and `asg-neo4j` has InService instances, then write `heavy-rental/ssh/{portal,rest,haystack,neo4j}` and install only the public key via SSM.

#### Scenario: Private key stays off the guest
- GIVEN four ASGs are InService
- WHEN `sync-ssh-keys` completes
- THEN each SSH secret contains `key_name`, `private_key_pem` (private OpenSSH key), and `public_key` (authorized_keys line)
- AND the instance `authorized_keys` contains the matching public key
- AND the private PEM is not written to the guest disk
- AND Terraform contains no `tls_private_key`

#### Scenario: Desired zero skips
- GIVEN an ASG desired capacity is 0
- WHEN `sync-ssh-keys` runs
- THEN that role’s PEM is not generated as a new apply-time key for missing guests
- AND the job fails closed asking the operator to apply or wait
