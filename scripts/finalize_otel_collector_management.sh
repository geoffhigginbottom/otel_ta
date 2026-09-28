#!/bin/bash
# Create OpAMP token and push it to OTel TA deployment-app configs after Splunk restart.
set -euo pipefail

PASSWORD="${1:-}"
if [ -z "${PASSWORD}" ] && [ -f /tmp/splunk_password ]; then
  PASSWORD=$(tr -d '\n' < /tmp/splunk_password)
fi
if [ -z "${PASSWORD}" ]; then
  echo "Admin password required (arg 1 or /tmp/splunk_password)." >&2
  exit 1
fi

SPLUNK_PRIVATE_IP="${2:-}"
if [ -z "${SPLUNK_PRIVATE_IP}" ] && [ -f /tmp/splunk_private_ip ]; then
  SPLUNK_PRIVATE_IP=$(tr -d '\n' < /tmp/splunk_private_ip)
fi
if [ -z "${SPLUNK_PRIVATE_IP}" ]; then
  echo "Splunk private IP required (arg 2 or /tmp/splunk_private_ip)." >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENABLE_SCRIPT="${SCRIPT_DIR}/enable_splunk_ent_otel_management.sh"
APPLY_SCRIPT="${SCRIPT_DIR}/apply_splunk_ent_opamp_deployment_configs.sh"
TOKEN_USER="admin"
TOKEN_AUDIENCE="general"
TOKEN_EXPIRES="+30d"
OPAMP_PORT=8089
TMP_TOKEN_FILE="/tmp/splunk_ent_opamp_token"
TMP_ENDPOINT_FILE="/tmp/splunk_ent_opamp_endpoint"
TMP_CREDENTIALS_FILE="/tmp/splunk_ent_opamp_credentials.json"

write_opamp_credentials_files() {
  local endpoint=$1
  local token=$2

  # Root cannot overwrite another user's files in sticky /tmp (fs.protected_regular).
  rm -f "${TMP_TOKEN_FILE}" "${TMP_ENDPOINT_FILE}" "${TMP_CREDENTIALS_FILE}"
  printf '%s' "${token}" > "${TMP_TOKEN_FILE}"
  printf '%s' "${endpoint}" > "${TMP_ENDPOINT_FILE}"
  python3 - <<PY "${TOKEN_USER}" "${TOKEN_AUDIENCE}" "${TOKEN_EXPIRES}" "${endpoint}" "${token}" "${TMP_CREDENTIALS_FILE}"
import json
import pathlib
import sys

pathlib.Path(sys.argv[6]).write_text(
    json.dumps(
        {
            "user": sys.argv[1],
            "audience": sys.argv[2],
            "expires_on": sys.argv[3],
            "endpoint": sys.argv[4],
            "token": sys.argv[5],
        },
        indent=2,
    )
    + "\n"
)
PY

  chmod 600 "${TMP_TOKEN_FILE}" "${TMP_ENDPOINT_FILE}" "${TMP_CREDENTIALS_FILE}"
  chown root:root "${TMP_TOKEN_FILE}" "${TMP_ENDPOINT_FILE}" "${TMP_CREDENTIALS_FILE}" 2>/dev/null || true
}

chmod +x "${ENABLE_SCRIPT}" "${APPLY_SCRIPT}"

echo "Creating Splunk Enterprise OTel Collector management token (user=${TOKEN_USER}, audience=${TOKEN_AUDIENCE}, expires=${TOKEN_EXPIRES})..."
OTEL_MGMT_TOKEN=$("${ENABLE_SCRIPT}" token "${PASSWORD}")
OPAMP_ENDPOINT="https://${SPLUNK_PRIVATE_IP}:${OPAMP_PORT}/services/tenant/agent-management/v2/opamp/otel"

write_opamp_credentials_files "${OPAMP_ENDPOINT}" "${OTEL_MGMT_TOKEN}"

echo "Applying OpAMP extension to all OTel deployment-app configs..."
"${APPLY_SCRIPT}" enable "${PASSWORD}" "${SPLUNK_PRIVATE_IP}" "${OPAMP_PORT}" "${OTEL_MGMT_TOKEN}"

echo "OTel Collector management token saved to:"
echo "  /opt/splunk/etc/auth/otel_collector_management/token"
echo "  ${TMP_TOKEN_FILE}"
echo "  ${TMP_ENDPOINT_FILE}"
echo "  ${TMP_CREDENTIALS_FILE}"
