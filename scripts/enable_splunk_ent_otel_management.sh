#!/bin/bash
# Configure Splunk Enterprise OTel Collector management and create an OpAMP auth token.
# Usage:
#   enable_splunk_ent_otel_management.sh conf
#   enable_splunk_ent_otel_management.sh token <admin_password>
#   enable_splunk_ent_otel_management.sh all <admin_password>
set -euo pipefail

MODE=${1:-all}
PASSWORD=${2:-}
SPLUNK="/opt/splunk/bin/splunk"
LOCAL_SERVER_CONF="/opt/splunk/etc/system/local/server.conf"
TOKEN_DIR="/opt/splunk/etc/auth/otel_collector_management"
TOKEN_FILE="${TOKEN_DIR}/token"
TOKEN_USER="admin"
TOKEN_AUDIENCE="general"
TOKEN_EXPIRES="+30d"
WRONG_AUDIENCES=("otel_agent_management")

fix_splunk_ownership() {
  chown -R splunk:splunk /opt/splunk
  find /opt/splunk/etc/system/local -type f -name '*.conf' -exec chmod 600 {} + 2>/dev/null || true
  [ -d "${TOKEN_DIR}" ] && chown -R splunk:splunk "${TOKEN_DIR}"
}

ensure_data_management_agent_role() {
  PASSWORD="${PASSWORD}" TOKEN_USER="${TOKEN_USER}" SPLUNK="${SPLUNK}" python3 - <<'PY'
import json
import os
import subprocess
import sys

password = os.environ["PASSWORD"]
user = os.environ["TOKEN_USER"]
splunk = os.environ["SPLUNK"]
role = "data_management_agent"

result = subprocess.run(
    [
        "curl",
        "-sk",
        "-u",
        f"admin:{password}",
        f"https://localhost:8089/services/authentication/users/{user}?output_mode=json",
    ],
    capture_output=True,
    text=True,
    check=False,
)
if result.returncode != 0 or not result.stdout.strip():
    sys.exit(0)

payload = json.loads(result.stdout)
roles = payload["entry"][0]["content"].get("roles", [])
if role in roles:
    sys.exit(0)

roles.append(role)
args = [
    "sudo",
    "-u",
    "splunk",
    splunk,
    "edit",
    "user",
    user,
    "-auth",
    f"admin:{password}",
]
for assigned in roles:
    args.extend(["-role", assigned])

print(f"Granting {role} role to {user}...", file=sys.stderr)
subprocess.run(args, check=True)
PY
}

revoke_wrong_audience_tokens() {
  PASSWORD="${PASSWORD}" TOKEN_USER="${TOKEN_USER}" TOKEN_AUDIENCE="${TOKEN_AUDIENCE}" \
    WRONG_AUDIENCES="${WRONG_AUDIENCES[*]}" python3 - <<'PY'
import json
import os
import subprocess
import sys

password = os.environ["PASSWORD"]
token_user = os.environ["TOKEN_USER"]
wanted_audience = os.environ["TOKEN_AUDIENCE"]
wrong_audiences = set(os.environ.get("WRONG_AUDIENCES", "").split())

result = subprocess.run(
    [
        "curl",
        "-sk",
        "-u",
        f"admin:{password}",
        "https://localhost:8089/services/authorization/tokens?output_mode=json",
    ],
    capture_output=True,
    text=True,
    check=False,
)
if result.returncode != 0 or not result.stdout.strip():
    sys.exit(0)

try:
    payload = json.loads(result.stdout)
except json.JSONDecodeError:
    sys.exit(0)

for entry in payload.get("entry", []):
    content = entry.get("content", {})
    name = content.get("name", "")
    audience = content.get("audience", "")
    token_id = entry.get("name", "")
    if name != token_user:
        continue
    if audience == wanted_audience:
        continue
    if wrong_audiences and audience not in wrong_audiences:
        continue
    print(f"Revoking token for {name} audience={audience} id={token_id}", file=sys.stderr)
    subprocess.run(
        [
            "curl",
            "-sk",
            "-u",
            f"admin:{password}",
            "-X",
            "DELETE",
            f"https://localhost:8089/services/authorization/tokens/{token_id}",
        ],
        check=False,
    )
PY
}

verify_token_audience() {
  local token=$1
  TOKEN="${token}" EXPECTED_AUDIENCE="${TOKEN_AUDIENCE}" python3 - <<'PY'
import base64
import json
import os
import sys

token = os.environ["TOKEN"]
expected = os.environ["EXPECTED_AUDIENCE"]
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
aud = json.loads(base64.urlsafe_b64decode(payload)).get("aud")
if aud != expected:
    print(
        f"Token JWT audience is {aud!r}, expected {expected!r}.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

enable_conf() {
  mkdir -p /opt/splunk/etc/system/local "${TOKEN_DIR}"

  if ! grep -q '^\[data_management\]' "${LOCAL_SERVER_CONF}" 2>/dev/null; then
    printf '\n[data_management]\n' >> "${LOCAL_SERVER_CONF}"
  fi

  if grep -q '^otel_collector_management_enabled' "${LOCAL_SERVER_CONF}"; then
    sed -i 's/^otel_collector_management_enabled.*/otel_collector_management_enabled = true/' "${LOCAL_SERVER_CONF}"
  else
    sed -i '/^\[data_management\]/a otel_collector_management_enabled = true' "${LOCAL_SERVER_CONF}"
  fi

  fix_splunk_ownership
}

create_token() {
  if [ -z "${PASSWORD}" ]; then
    echo "Admin password required for token creation." >&2
    exit 1
  fi

  mkdir -p "${TOKEN_DIR}"
  rm -f "${TOKEN_FILE}"

  curl -skf -u "admin:${PASSWORD}" \
    -X POST "https://localhost:8089/services/admin/token-auth/tokens_auth" \
    -d disabled=false >/dev/null

  ensure_data_management_agent_role
  revoke_wrong_audience_tokens

  RESP=$(curl -sk -u "admin:${PASSWORD}" \
    -X POST "https://localhost:8089/services/authorization/tokens?output_mode=json" \
    --data "name=${TOKEN_USER}" \
    --data "audience=${TOKEN_AUDIENCE}" \
    --data "type=static" \
    --data-urlencode "expires_on=${TOKEN_EXPIRES}")

  if ! echo "${RESP}" | python3 -c 'import json,sys; json.load(sys.stdin)["entry"][0]["content"]["token"]' >/dev/null 2>&1; then
    echo "Failed to create Splunk Enterprise OTel management token: ${RESP}" >&2
    exit 1
  fi

  TOKEN=$(echo "${RESP}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry"][0]["content"]["token"])')

  verify_token_audience "${TOKEN}"

  printf '%s' "${TOKEN}" > "${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}"
  fix_splunk_ownership

  printf '%s' "${TOKEN}"
}

case "${MODE}" in
  conf)
    enable_conf
    ;;
  token)
    create_token
    ;;
  all)
    enable_conf
    create_token
    ;;
  *)
    echo "Usage: $0 conf|token|all [admin_password]" >&2
    exit 1
    ;;
esac
