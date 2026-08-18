# Tasks: add-infra-academy-deploy-projects

## 1. Spec + ADR

- [x] 1.1 Proposal, design, tasks, deploy-projects spec + scope/ansible deltas
- [x] 1.2 OpenSPDD analysis + REASONS Canvas
- [x] 1.3 ADR 0014
- [x] 1.4 Update living indexes (specification, BOOTSTRAP, ARCHITECTURE, README)

## 2. Workflow

- [x] 2.1 Add `deploy-projects` to `workflow_dispatch` choices
- [x] 2.2 Include action in `sync-secrets` / `sync-ssh-keys` `if:`
- [x] 2.3 New job: preflight images + ASGs, then `site.yml` only
- [x] 2.4 Keep apply / configure-only on `configure.yml`

## 3. Ansible

- [x] 3.1 Haystack aliases + `uv run` sidecars (match app CD)
- [x] 3.2 `site.yml` header: invoked only by `deploy-projects`
