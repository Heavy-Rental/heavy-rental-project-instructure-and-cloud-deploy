# Delta for infra-academy-sync-ssh (bastion hop)

## MODIFIED Requirements

### Requirement: PEMs after InService
`sync-ssh-keys` SHALL wait until the four app ASGs are InService **and** `hr-bastion` is running, then write `heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion}` with `key_name`, `private_key_pem` (the **private** OpenSSH key), and `public_key` (the authorized_keys line). App guests SHALL receive **only** the public key via SSM. `hr-bastion` SHALL receive the hop **private** key at `/home/ec2-user/.ssh/id_ed25519` **and** copies of the four role private keys at `/home/ec2-user/.ssh/id_{portal,rest,haystack,neo4j}`. Host aliases from `hr-ssh-config` SHALL set `IdentityFile` to that role key and the hop key. Operators SHALL NOT write SSH config: interactive SSM on the bastion SHALL become `ec2-user`, and `hr-ssh` SHALL hop as `ec2-user` if the shell is still `ssm-user`.

#### Scenario: Hop PEM stays off app guests
- GIVEN four app ASGs are InService and `hr-bastion` is running
- WHEN `sync-ssh-keys` completes
- THEN `heavy-rental/ssh/bastion` contains `private_key_pem` (private key) and `public_key`
- AND each of `heavy-rental/ssh/{portal,rest,haystack,neo4j}` contains `private_key_pem` and `public_key`
- AND portal / rest / haystack / neo4j `authorized_keys` contain the bastion public key
- AND those four roles do not have `/home/ec2-user/.ssh/id_ed25519` or `id_{portal,rest,haystack,neo4j}` from this job
- AND `hr-bastion` has `/home/ec2-user/.ssh/id_ed25519` and `/home/ec2-user/.ssh/id_{portal,rest,haystack,neo4j}`
- AND `hr-bastion` `~/.ssh/config` has Host aliases (`portal`, `rest-1`, …) with `IdentityFile` for that role
- AND `/etc/profile.d/hr-ssm-ec2-user.sh` exists so interactive SSM becomes `ec2-user`
- AND `/usr/local/bin/hr-ssh` hops as `ec2-user`
