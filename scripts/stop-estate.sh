#!/usr/bin/env bash
# Pause: ASG desired=0 (keep max=2) + stop both RDS. NAT Gateways stay and still bill.
set -euo pipefail

ASGS=(asg-portal asg-rest asg-haystack asg-neo4j)
RDS_IDS=(heavy-rental-academy heavy-rental-haystack-academy)

for asg in "${ASGS[@]}"; do
  if aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${asg}" \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text 2>/dev/null | grep -q "${asg}"; then
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "${asg}" \
      --min-size 0 --desired-capacity 0 --max-size 2
    echo "${asg}: desired=0 min=0 max=2."
  else
    echo "${asg}: missing, skipped."
  fi
done

for id in "${RDS_IDS[@]}"; do
  status="$(aws rds describe-db-instances --db-instance-identifier "${id}" \
    --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo missing)"
  case "${status}" in
    available)
      aws rds stop-db-instance --db-instance-identifier "${id}" >/dev/null
      echo "${id}: stop requested."
      ;;
    stopped|stopping)
      echo "${id}: already ${status}."
      ;;
    missing)
      echo "${id}: missing, skipped."
      ;;
    *)
      echo "${id}: status ${status}; not stopping."
      ;;
  esac
done

echo "stop is pause. NAT Gateways, EIPs, ALBs, NLB, and the VPC were not deleted and still bill."
