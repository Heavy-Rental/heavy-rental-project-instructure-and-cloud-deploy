# Delta for infra-academy-estate-apply (branch 3)

## Purpose

`action=apply` still creates the estate, then configures guests.

## MODIFIED Requirements

### Requirement: Apply continues to configure
After a successful estate apply, the workflow SHALL run `sync-secrets`, `sync-ssh-keys`, and Ansible.

#### Scenario: Apply is not estate-only
- GIVEN `action=apply` and Terraform apply succeeded
- WHEN the workflow finishes
- THEN `sync-secrets` has written required JSON
- AND Ansible has run against the four groups (or failed closed on a missing REST/Haystack image)
