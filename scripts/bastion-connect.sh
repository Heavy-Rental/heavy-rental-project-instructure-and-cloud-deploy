#!/usr/bin/env bash
# Print how to reach hr-bastion and SSH from there to app guests.
# Does not print PEMs. Requires AWS CLI credentials for the lab/account.
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

id="$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Role,Values=bastion" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId | [0]' \
  --output text 2>/dev/null || true)"

if [ -z "${id}" ] || [ "${id}" = "None" ]; then
  echo "hr-bastion has no running instance. Run action=apply first." >&2
  exit 1
fi

read -r public_ip private_ip <<<"$(aws ec2 describe-instances \
  --instance-ids "${id}" \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]' \
  --output text)"

echo "Maintenance bastion"
echo "  instance:   ${id}"
echo "  public IP:  ${public_ip:-none}"
echo "  private IP: ${private_ip}"
echo "  region:     ${REGION}"
echo
echo "1) SSM onto the bastion (works with empty BASTION_SSH_CIDRS):"
echo "     aws ssm start-session --target ${id} --region ${REGION}"
echo "   The session becomes ec2-user (private keys + Host aliases). Do not write SSH config."
echo "   Secrets Manager private_key_pem is the *private* key, not the public .pub line."
echo "   Then on the bastion:"
echo "     hr-ssh-targets          # refresh + list Host aliases"
echo "     ssh portal              # or rest, haystack, neo4j"
echo "     ssh rest-2              # second guest of that role"
echo "     ssh haystack-1a         # by AZ suffix"
echo "     hr-ssh portal           # same hop if the shell is still ssm-user"
echo "     hr-ssh-pull-keys        # re-read private keys from Secrets Manager"
echo
if [ -n "${public_ip}" ] && [ "${public_ip}" != "None" ]; then
  echo "2) ProxyJump from a laptop (requires BASTION_SSH_CIDRS to include your /32):"
  echo "     aws secretsmanager get-secret-value --secret-id heavy-rental/ssh/bastion \\"
  echo "       --query SecretString --output text | jq -r .private_key_pem > bastion.pem"
  echo "     chmod 600 bastion.pem"
  echo "     ssh -i bastion.pem -J ec2-user@${public_ip} ec2-user@<guest-private-ip>"
  echo "   Named hosts (portal, rest-2, ...) exist only on the bastion, not on your laptop."
else
  echo "2) ProxyJump is unavailable until the instance has a public IP."
fi
echo
echo "App guests never accept SSH from 0.0.0.0/0; only sg-bastion :22."
