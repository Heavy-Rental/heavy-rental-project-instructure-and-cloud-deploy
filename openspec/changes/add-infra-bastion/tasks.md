# Tasks: add-infra-bastion

- [x] 1. `sg-bastion` + app `:22` from bastion only; no `0.0.0.0/0` on `:22`
- [x] 2. `hr-bastion` single EC2 in a public subnet, public IP; no ASG
- [x] 3. SM shell `heavy-rental/ssh/bastion`; paid `hr-paid-bastion`
- [x] 4. `sync-ssh-keys` hop public key on all guests; private key on bastion only
- [x] 5. `stop` / sweep / reconcile / destroy include `hr-bastion`
- [x] 6. Inventory group `bastion`; compose playbooks do not target it
- [x] 7. ADR 0021, operator helper, Architecture / OPERATOR-GUIDE
- [x] 8. Specs + docs: single `hr-bastion` EC2 (not ASG); hop Host aliases; stop uses `stop-instances`
