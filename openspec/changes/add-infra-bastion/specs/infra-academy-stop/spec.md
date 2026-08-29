# Delta for infra-academy-stop (bastion)

## MODIFIED Requirements

### Requirement: Pause ASGs and both RDS
`action=stop` SHALL also `stop-instances` on `hr-bastion` (tag `Role=bastion`). App ASGs keep max=2.

#### Scenario: Bastion is stopped, not deleted
- GIVEN `action=stop` succeeds
- WHEN `hr-bastion` is described
- THEN its state is `stopping` or `stopped`
- AND the instance still exists
