# Specification (Academy infra CD)

Conflict order: **OpenSpec scenarios → OpenSPDD Safeguards → ADR → YAML / Terraform**. If YAML cannot satisfy a scenario without breaking a safeguard, update the spec first.

| Kind | Path | Role |
| --- | --- | --- |
| **OpenSpec** | [`../openspec/`](../openspec/) | Observable behavior (SHALL + GIVEN/WHEN/THEN) |
| **OpenSPDD** | [`../spdd/`](../spdd/) | REASONS Canvas + analysis (how to implement, what not to invent) |
| **ADR** | [`../docs/adr/`](../docs/adr/) | Why Vocareum-only, Environment secrets, remote state, two NAT Gateways, PEMs after InService, Ansible over SSM |
| **Operator** | [`../BOOTSTRAP.md`](../BOOTSTRAP.md) | Environment `academy`, every Start Lab, `apply` / `configure-only` / `stop` |
| **Program plan** | [`../IMPLEMENTATION-PLAN.md`](../IMPLEMENTATION-PLAN.md) | Three-branch delivery |

Current change: [`../openspec/changes/add-infra-academy-configure/`](../openspec/changes/add-infra-academy-configure/).  
Previous: [`../openspec/changes/add-infra-academy-estate/`](../openspec/changes/add-infra-academy-estate/).
