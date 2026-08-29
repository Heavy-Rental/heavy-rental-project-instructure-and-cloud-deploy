#!/usr/bin/env bash
# After ASGs are InService: PEM in Secrets Manager, public key via SSM.
# Never log the PEM. App guests never get a private key (ADR 0011).
# The maintenance bastion is the exception (ADR 0021): it receives the hop
# private key so SSM-then-SSH to portal/rest/haystack/neo4j works.
set +x
set -euo pipefail

APP_ASGS=(asg-portal asg-rest asg-haystack asg-neo4j)
APP_ROLES=(portal rest haystack neo4j)
BASTION_ROLE="bastion"
TIMEOUT="${SSH_WAIT_TIMEOUT:-900}"

wait_inservice() {
  local asg="$1"
  local start
  start="$(date +%s)"
  while true; do
    local desired in_svc
    desired="$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg}" \
      --query 'AutoScalingGroups[0].DesiredCapacity' --output text 2>/dev/null || echo none)"
    if [ "${desired}" = "none" ] || [ "${desired}" = "None" ] || [ -z "${desired}" ]; then
      echo "::error::${asg} is missing. Apply the estate first."
      exit 1
    fi
    if [ "${desired}" = "0" ]; then
      echo "::error::${asg} desired=0. Run apply or scale the group before sync-ssh-keys."
      exit 1
    fi
    in_svc="$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg}" \
      --query 'length(AutoScalingGroups[0].Instances[?LifecycleState==`InService`])' \
      --output text)"
    if [ "${in_svc}" -ge "${desired}" ]; then
      echo "${asg}: ${in_svc} InService (desired ${desired})."
      return 0
    fi
    if [ $(( $(date +%s) - start )) -ge "${TIMEOUT}" ]; then
      echo "::error::Timed out waiting for ${asg} InService (have ${in_svc}, want ${desired})."
      exit 1
    fi
    sleep 15
  done
}

instance_ids() {
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$1" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text
}

bastion_id() {
  aws ec2 describe-instances \
    --filters \
      "Name=tag:Role,Values=bastion" \
      "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId | [0]' \
    --output text 2>/dev/null || true
}

wait_bastion_running() {
  local start id
  start="$(date +%s)"
  while true; do
    id="$(bastion_id)"
    if [ -n "${id}" ] && [ "${id}" != "None" ]; then
      echo "hr-bastion: ${id} running."
      return 0
    fi
    if [ $(( $(date +%s) - start )) -ge "${TIMEOUT}" ]; then
      echo "::error::Timed out waiting for hr-bastion (tag Role=bastion) to be running."
      exit 1
    fi
    sleep 15
  done
}

ensure_key() {
  local role="$1"
  local secret_id="heavy-rental/ssh/${role}"
  local key_name="hr-academy-${role}"
  local key_file="${WORKDIR}/${role}"

  existing="$(aws secretsmanager get-secret-value --secret-id "${secret_id}" \
    --query SecretString --output text 2>/dev/null || true)"
  if echo "${existing}" | jq -e '.private_key_pem | type=="string" and length>20' >/dev/null 2>&1; then
    echo "${secret_id}: reusing existing PEM."
    echo "${existing}" | jq -r '.private_key_pem' >"${key_file}"
    chmod 600 "${key_file}"
    ssh-keygen -y -f "${key_file}" >"${key_file}.pub"
  else
    ssh-keygen -t ed25519 -N '' -C "${key_name}" -f "${key_file}" >/dev/null
    pem="$(cat "${key_file}")"
    echo "::add-mask::${pem}"
    jq -n --arg key_name "${key_name}" --arg private_key_pem "${pem}" \
      '{key_name:$key_name,private_key_pem:$private_key_pem}' >"${WORKDIR}/${role}.json"
    aws secretsmanager put-secret-value \
      --secret-id "${secret_id}" \
      --secret-string "file://${WORKDIR}/${role}.json" \
      >/dev/null
  fi
}

install_public_key() {
  local asg="$1"
  local key_name="$2"
  local pub="$3"
  local ids
  ids="$(instance_ids "${asg}")"
  if [ -z "${ids}" ]; then
    echo "::error::No InService instances on ${asg}."
    exit 1
  fi
  # shellcheck disable=SC2086
  aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "install ${key_name} public key" \
    --instance-ids ${ids} \
    --parameters "commands=[
      \"set -euo pipefail\",
      \"install -d -m 700 -o ec2-user -g ec2-user /home/ec2-user/.ssh\",
      \"touch /home/ec2-user/.ssh/authorized_keys\",
      \"chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys\",
      \"chmod 600 /home/ec2-user/.ssh/authorized_keys\",
      \"grep -qxF '${pub}' /home/ec2-user/.ssh/authorized_keys || echo '${pub}' >> /home/ec2-user/.ssh/authorized_keys\"
    ]" \
    >/dev/null
}

b64_file() {
  base64 -w0 "$1" 2>/dev/null || base64 "$1" | tr -d '\n'
}

install_bastion_hop_key() {
  local ids key_b64 helper_b64 wrapper_b64 hook_b64 params script_dir
  ids="$(bastion_id)"
  if [ -z "${ids}" ] || [ "${ids}" = "None" ]; then
    echo "::error::No running hr-bastion instance (tag Role=bastion)."
    exit 1
  fi
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  key_b64="$(b64_file "${WORKDIR}/${BASTION_ROLE}")"
  echo "::add-mask::${key_b64}"
  helper_b64="$(b64_file "${script_dir}/bastion-hr-ssh-config.sh")"
  printf '%s\n' '#!/bin/bash' 'exec /usr/local/bin/hr-ssh-config --list' \
    >"${WORKDIR}/hr-ssh-targets"
  wrapper_b64="$(b64_file "${WORKDIR}/hr-ssh-targets")"
  printf '%s\n' \
    '' \
    '# heavy-rental hr-ssh-config' \
    'if [ -x /usr/local/bin/hr-ssh-config ]; then' \
    '  /usr/local/bin/hr-ssh-config >/dev/null 2>&1 || true' \
    'fi' >"${WORKDIR}/bashrc-hook"
  hook_b64="$(b64_file "${WORKDIR}/bashrc-hook")"
  params="$(jq -n --arg key "${key_b64}" --arg helper "${helper_b64}" \
    --arg wrapper "${wrapper_b64}" --arg hook "${hook_b64}" '{
    commands: [
      "set -euo pipefail",
      "install -d -m 700 -o ec2-user -g ec2-user /home/ec2-user/.ssh",
      ("printf %s " + $key + " | base64 -d > /home/ec2-user/.ssh/id_ed25519"),
      "chown ec2-user:ec2-user /home/ec2-user/.ssh/id_ed25519",
      "chmod 600 /home/ec2-user/.ssh/id_ed25519",
      ("printf %s " + $helper + " | base64 -d > /usr/local/bin/hr-ssh-config"),
      "chmod 755 /usr/local/bin/hr-ssh-config",
      ("printf %s " + $wrapper + " | base64 -d > /usr/local/bin/hr-ssh-targets"),
      "chmod 755 /usr/local/bin/hr-ssh-targets",
      "touch /home/ec2-user/.bashrc",
      "chown ec2-user:ec2-user /home/ec2-user/.bashrc",
      ("grep -qF hr-ssh-config /home/ec2-user/.bashrc || printf %s " + $hook + " | base64 -d >> /home/ec2-user/.bashrc"),
      "/usr/local/bin/hr-ssh-config"
    ]
  }')"
  # shellcheck disable=SC2086
  aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "install bastion hop key and SSH guest aliases" \
    --instance-ids ${ids} \
    --parameters "${params}" \
    >/dev/null
}

for asg in "${APP_ASGS[@]}"; do
  wait_inservice "${asg}"
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

for i in "${!APP_ROLES[@]}"; do
  role="${APP_ROLES[$i]}"
  asg="${APP_ASGS[$i]}"
  ensure_key "${role}"
  install_public_key "${asg}" "hr-academy-${role}" "$(cat "${WORKDIR}/${role}.pub")"
  echo "${asg}: public key installed via SSM (PEM not on guest)."
done

bid="$(bastion_id)"
if [ -n "${bid}" ] && [ "${bid}" != "None" ]; then
  wait_bastion_running
  ensure_key "${BASTION_ROLE}"
  bastion_pub="$(cat "${WORKDIR}/${BASTION_ROLE}.pub")"
  aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "install hr-academy-${BASTION_ROLE} public key" \
    --instance-ids "$(bastion_id)" \
    --parameters "commands=[
      \"set -euo pipefail\",
      \"install -d -m 700 -o ec2-user -g ec2-user /home/ec2-user/.ssh\",
      \"touch /home/ec2-user/.ssh/authorized_keys\",
      \"chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys\",
      \"chmod 600 /home/ec2-user/.ssh/authorized_keys\",
      \"grep -qxF '${bastion_pub}' /home/ec2-user/.ssh/authorized_keys || echo '${bastion_pub}' >> /home/ec2-user/.ssh/authorized_keys\"
    ]" \
    >/dev/null
  for asg in "${APP_ASGS[@]}"; do
    install_public_key "${asg}" "hr-academy-${BASTION_ROLE}" "${bastion_pub}"
  done
  install_bastion_hop_key
  echo "hr-bastion: hop private key on bastion; public key on all guests; SSH Host aliases (ssh portal / rest-2 / ...)."
else
  echo "::warning::hr-bastion is missing. Re-run action=apply to create the maintenance bastion. App PEMs were still written."
fi

echo "SSH secrets written. Private keys not printed."
