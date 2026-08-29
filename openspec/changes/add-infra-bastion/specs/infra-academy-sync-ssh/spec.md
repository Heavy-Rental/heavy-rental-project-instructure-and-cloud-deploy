# Delta for infra-academy-sync-ssh (bastion hop)

## MODIFIED Requirements

### Requirement: PEMs after InService
`sync-ssh-keys` SHALL wait until the four app ASGs are InService **and** `hr-bastion` is running, then write `heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion}`. App guests SHALL receive **only** the public key via SSM. `hr-bastion` SHALL receive the hop **private** key at `/home/ec2-user/.ssh/id_ed25519` and Host aliases from `hr-ssh-config`.

#### Scenario: Hop PEM stays off app guests
- GIVEN four app ASGs are InService and `hr-bastion` is running
- WHEN `sync-ssh-keys` completes
- THEN `heavy-rental/ssh/bastion` contains `private_key_pem`
- AND portal / rest / haystack / neo4j `authorized_keys` contain the bastion public key
- AND those four roles do not have `/home/ec2-user/.ssh/id_ed25519` from this job
- AND `hr-bastion` `~/.ssh/config` has Host aliases (`portal`, `rest-1`, …)
