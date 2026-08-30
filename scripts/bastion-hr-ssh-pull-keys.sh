#!/bin/bash
# On hr-bastion: refresh OpenSSH *private* keys from Secrets Manager.
# heavy-rental/ssh/{portal,rest,haystack,neo4j,bastion} .private_key_pem
# is the private key (BEGIN OPENSSH PRIVATE KEY), not the .pub line.
# Never prints PEMs.
set -euo pipefail

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

if [ "$(id -u)" -eq 0 ]; then
  SSH_DIR="/home/ec2-user/.ssh"
  OWNER="ec2-user"
else
  SSH_DIR="${HOME}/.ssh"
  OWNER="$(id -un)"
fi

install -d -m 700 -o "${OWNER}" -g "${OWNER}" "${SSH_DIR}"

write_pem() {
  local secret_id="$1"
  local dest="$2"
  local pem
  pem="$(aws secretsmanager get-secret-value \
    --secret-id "${secret_id}" \
    --query SecretString --output text 2>/dev/null \
    | jq -r '.private_key_pem // empty')"
  if [ -z "${pem}" ] || [ "${pem}" = "null" ]; then
    echo "skip ${secret_id}: no private_key_pem" >&2
    return 0
  fi
  umask 077
  printf '%s\n' "${pem}" >"${dest}"
  chown "${OWNER}:${OWNER}" "${dest}"
  chmod 600 "${dest}"
}

write_pem "heavy-rental/ssh/bastion" "${SSH_DIR}/id_ed25519"
write_pem "heavy-rental/ssh/portal" "${SSH_DIR}/id_portal"
write_pem "heavy-rental/ssh/rest" "${SSH_DIR}/id_rest"
write_pem "heavy-rental/ssh/haystack" "${SSH_DIR}/id_haystack"
write_pem "heavy-rental/ssh/neo4j" "${SSH_DIR}/id_neo4j"

if [ -x /usr/local/bin/hr-ssh-config ]; then
  /usr/local/bin/hr-ssh-config >/dev/null 2>&1 || true
fi
