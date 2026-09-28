#!/bin/bash
# Apply Splunk Enterprise OpAMP settings to all OTel deployment-app configs.
#
# Usage:
#   apply_splunk_ent_opamp_deployment_configs.sh enable <admin_password> <host> [port] [token]
#   apply_splunk_ent_opamp_deployment_configs.sh disable <admin_password>
#
# On enable, patches every OTel agent YAML with OpAMP placeholders (${SPLUNK_ENT_OPAMP_*}),
# sets the real endpoint and token in inputs.conf splunk_collector_env_vars, and reloads deploy-server.
#
# If token is omitted, reads /tmp/splunk_ent_opamp_token or creates one via enable script.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PATCH_SCRIPT="${SCRIPT_DIR}/patch_otel_splunk_ent_opamp.sh"
ENABLE_SCRIPT="${SCRIPT_DIR}/enable_splunk_ent_otel_management.sh"
SPLUNK="/opt/splunk/bin/splunk"
DEFAULT_PORT=8089
OPAMP_PATH="/services/tenant/agent-management/v2/opamp/otel"

OTEL_APP_INPUTS=(
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_windows/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/local/inputs.conf
  /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/local/inputs.conf
)

build_endpoint() {
  local host=$1
  local port=$2
  printf 'https://%s:%s%s' "${host}" "${port}" "${OPAMP_PATH}"
}

merge_opamp_env_vars() {
  local file=$1
  local endpoint=$2
  local token=$3

  [ -f "${file}" ] || return 0

  ENDPOINT="${endpoint}" TOKEN="${token}" INPUTS_FILE="${file}" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["INPUTS_FILE"])
endpoint = os.environ["ENDPOINT"]
token = os.environ["TOKEN"]
text = path.read_text()

opamp_vars = f"SPLUNK_ENT_OPAMP_ENDPOINT={endpoint},SPLUNK_ENT_OPAMP_TOKEN={token}"

if "SPLUNK_ENT_OPAMP_ENDPOINT=" in text:
    text = re.sub(r"SPLUNK_ENT_OPAMP_ENDPOINT=[^,\n]*", f"SPLUNK_ENT_OPAMP_ENDPOINT={endpoint}", text)
    text = re.sub(r"SPLUNK_ENT_OPAMP_TOKEN=[^,\n]*", f"SPLUNK_ENT_OPAMP_TOKEN={token}", text)
elif re.search(r"^splunk_collector_env_vars\s*=", text, re.M):
    text = re.sub(
        r"^(splunk_collector_env_vars\s*=\s*)(.*)$",
        lambda m: f"{m.group(1)}{m.group(2).rstrip(',')},{opamp_vars}" if m.group(2).strip() else f"{m.group(1)}{opamp_vars}",
        text,
        count=1,
        flags=re.M,
    )
else:
    stanza = "[Splunk_TA_otel://Splunk_TA_otel]"
    if stanza in text:
        text = text.replace(
            stanza + "\n",
            stanza + f"\nsplunk_collector_env_vars = {opamp_vars}\n",
            1,
        )

path.write_text(text)
PY

  chown splunk:splunk "${file}" 2>/dev/null || true
}

strip_opamp_env_vars() {
  local file=$1

  [ -f "${file}" ] || return 0

  INPUTS_FILE="${file}" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["INPUTS_FILE"])
text = path.read_text()
text = re.sub(r",?SPLUNK_ENT_OPAMP_ENDPOINT=[^,\n]*", "", text)
text = re.sub(r",?SPLUNK_ENT_OPAMP_TOKEN=[^,\n]*", "", text)
text = re.sub(r"^splunk_collector_env_vars\s*=\s*,", "splunk_collector_env_vars = ", text, flags=re.M)
text = re.sub(r"^splunk_collector_env_vars\s*=\s*$", "", text, flags=re.M)
path.write_text(text)
PY

  chown splunk:splunk "${file}" 2>/dev/null || true
}

MODE=${1:?mode required: enable or disable}
PASSWORD=${2:?admin password required}

case "${MODE}" in
  enable)
    HOST=${3:?host required}
    PORT=${4:-${DEFAULT_PORT}}
    TOKEN=${5:-}

    if [ -z "${TOKEN}" ]; then
      if [ -f /tmp/splunk_ent_opamp_token ]; then
        TOKEN=$(tr -d '\n' < /tmp/splunk_ent_opamp_token)
      elif [ -f /opt/splunk/etc/auth/otel_collector_management/token ]; then
        TOKEN=$(tr -d '\n' < /opt/splunk/etc/auth/otel_collector_management/token)
      else
        chmod +x "${ENABLE_SCRIPT}"
        TOKEN=$("${ENABLE_SCRIPT}" token "${PASSWORD}")
      fi
    fi

    ENDPOINT=$(build_endpoint "${HOST}" "${PORT}")

    chmod +x "${PATCH_SCRIPT}"
    echo "Patching OTel agent YAML configs with OpAMP extension (env var placeholders)..."
    "${PATCH_SCRIPT}" enable-placeholder

    echo "Setting SPLUNK_ENT_OPAMP_ENDPOINT and SPLUNK_ENT_OPAMP_TOKEN in inputs.conf..."

    echo "Updating OTel TA inputs.conf env vars..."
    for inputs_file in "${OTEL_APP_INPUTS[@]}"; do
      merge_opamp_env_vars "${inputs_file}" "${ENDPOINT}" "${TOKEN}"
    done

    chown -R splunk:splunk /opt/splunk/etc/deployment-apps 2>/dev/null || true
  ;;
  disable)
    chmod +x "${PATCH_SCRIPT}"
    echo "Removing OpAMP extension from OTel agent YAML configs..."
    "${PATCH_SCRIPT}" disable
    echo "Removing OpAMP env vars from inputs.conf..."
    for inputs_file in "${OTEL_APP_INPUTS[@]}"; do
      strip_opamp_env_vars "${inputs_file}"
    done
    chown -R splunk:splunk /opt/splunk/etc/deployment-apps 2>/dev/null || true
  ;;
  *)
    echo "Usage: $0 enable <admin_password> <host> [port] [token]" >&2
    echo "       $0 disable <admin_password>" >&2
    exit 1
    ;;
esac

sudo -u splunk "${SPLUNK}" reload deploy-server -auth "admin:${PASSWORD}"
echo "Deployment server reloaded."
