#!/bin/bash
# Fetch Splunk Enterprise OpAMP token artifacts from the deployment server to .generated/
# Usage: fetch_splunk_opamp_token.sh <private_key_path> <eip> <gen_dir> <opamp_endpoint>
set -euo pipefail

PRIVATE_KEY_PATH=${1:?private key path required}
EIP=${2:?eip required}
GEN_DIR=${3:?output directory required}
ENDPOINT=${4:?opamp endpoint required}
EXPECTED_AUDIENCE="general"

mkdir -p "${GEN_DIR}"
rm -f \
  "${GEN_DIR}/splunk_ent_opamp_token" \
  "${GEN_DIR}/splunk_ent_opamp_endpoint" \
  "${GEN_DIR}/splunk_ent_opamp_credentials.json"

TOKEN=$(ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY_PATH}" "ubuntu@${EIP}" \
  'sudo cat /tmp/splunk_ent_opamp_token 2>/dev/null || true' \
  | tr -d '\n')

if [ -z "${TOKEN}" ]; then
  TOKEN=$(ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY_PATH}" "ubuntu@${EIP}" \
    'sudo cat /opt/splunk/etc/auth/otel_collector_management/token 2>/dev/null || true' \
    | tr -d '\n')
fi

if [ -z "${TOKEN}" ]; then
  echo "Splunk OpAMP token not found on ${EIP}. Ensure certs/finalize completed successfully." >&2
  exit 1
fi

TOKEN_AUD=$(TOKEN="${TOKEN}" python3 - <<'PY'
import base64
import json
import os

token = os.environ["TOKEN"]
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
print(json.loads(base64.urlsafe_b64decode(payload))["aud"])
PY
)

if [ "${TOKEN_AUD}" != "${EXPECTED_AUDIENCE}" ]; then
  echo "Splunk OpAMP token audience is '${TOKEN_AUD}', expected '${EXPECTED_AUDIENCE}'." >&2
  echo "Re-run certs/finalize with updated scripts on ${EIP}." >&2
  exit 1
fi

printf '%s' "${TOKEN}" > "${GEN_DIR}/splunk_ent_opamp_token"
printf '%s' "${ENDPOINT}" > "${GEN_DIR}/splunk_ent_opamp_endpoint"

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg user "admin" \
    --arg audience "${EXPECTED_AUDIENCE}" \
    --arg expires_on "+30d" \
    --arg endpoint "${ENDPOINT}" \
    --arg token "${TOKEN}" \
    '{user: $user, audience: $audience, expires_on: $expires_on, endpoint: $endpoint, token: $token}' \
    > "${GEN_DIR}/splunk_ent_opamp_credentials.json"
else
  TOKEN="${TOKEN}" ENDPOINT="${ENDPOINT}" EXPECTED_AUDIENCE="${EXPECTED_AUDIENCE}" GEN_DIR="${GEN_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

gen_dir = Path(os.environ["GEN_DIR"])
gen_dir.joinpath("splunk_ent_opamp_credentials.json").write_text(
    json.dumps(
        {
            "user": "admin",
            "audience": os.environ["EXPECTED_AUDIENCE"],
            "expires_on": "+30d",
            "endpoint": os.environ["ENDPOINT"],
            "token": os.environ["TOKEN"],
        },
        indent=2,
    )
    + "\n"
)
PY
fi

for artifact in \
  "${GEN_DIR}/splunk_ent_opamp_token" \
  "${GEN_DIR}/splunk_ent_opamp_endpoint" \
  "${GEN_DIR}/splunk_ent_opamp_credentials.json"
do
  if [ ! -s "${artifact}" ]; then
    echo "Failed to write non-empty OpAMP artifact: ${artifact}" >&2
    exit 1
  fi
done
