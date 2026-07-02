#!/bin/bash
# Enable Splunk Enterprise OTel Collector management and create an OpAMP auth token.
set -euo pipefail

PASSWORD=$1
SPLUNK="/opt/splunk/bin/splunk"
LOCAL_SERVER_CONF="/opt/splunk/etc/system/local/server.conf"
TOKEN_DIR="/opt/splunk/etc/auth/otel_collector_management"
TOKEN_FILE="${TOKEN_DIR}/token"

mkdir -p /opt/splunk/etc/system/local "${TOKEN_DIR}"

if ! grep -q '^\[data_management\]' "${LOCAL_SERVER_CONF}" 2>/dev/null; then
  printf '\n[data_management]\n' >> "${LOCAL_SERVER_CONF}"
fi

if grep -q '^otel_collector_management_enabled' "${LOCAL_SERVER_CONF}"; then
  sed -i 's/^otel_collector_management_enabled.*/otel_collector_management_enabled = true/' "${LOCAL_SERVER_CONF}"
else
  sed -i '/^\[data_management\]/a otel_collector_management_enabled = true' "${LOCAL_SERVER_CONF}"
fi

# Token auth must be enabled (install script usually does this already).
curl -skf -u "admin:${PASSWORD}" \
  -X POST "https://localhost:8089/services/admin/token-auth/tokens_auth" \
  -d disabled=false >/dev/null

RESP=$(curl -sk -u "admin:${PASSWORD}" \
  -X POST "https://localhost:8089/services/authorization/tokens?output_mode=json" \
  --data "name=admin" \
  --data "audience=otel_agent_management" \
  --data "type=static" \
  --data-urlencode "expires_on=+365d")

if ! echo "${RESP}" | python3 -c 'import json,sys; json.load(sys.stdin)["entry"][0]["content"]["token"]' >/dev/null 2>&1; then
  echo "Failed to create Splunk Enterprise OTel management token: ${RESP}" >&2
  exit 1
fi

TOKEN=$(echo "${RESP}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry"][0]["content"]["token"])')

printf '%s' "${TOKEN}" > "${TOKEN_FILE}"
chown splunk:splunk "${TOKEN_FILE}" "${LOCAL_SERVER_CONF}"
chmod 600 "${TOKEN_FILE}"
chmod 600 "${LOCAL_SERVER_CONF}"

sudo -u splunk "${SPLUNK}" restart --accept-license --answer-yes --no-prompt

printf '%s' "${TOKEN}"
