#!/bin/bash
# Add or remove Splunk Enterprise OpAMP (agent management) settings in OTel YAML configs.
#
# Usage:
#   patch_otel_splunk_ent_opamp.sh enable <endpoint> <token> [config.yaml ...]
#   patch_otel_splunk_ent_opamp.sh enable-placeholder [config.yaml ...]
#   patch_otel_splunk_ent_opamp.sh disable [config.yaml ...]
#
# Legacy aliases: true -> enable-placeholder, false -> disable
#
# When no config files are listed, all OTel agent YAML files under deployment-apps are updated.
set -euo pipefail

discover_otel_agent_configs() {
  find /opt/splunk/etc/deployment-apps -type f \( \
    -path '*/configs/*otel*.yaml' -o \
    -path '*/configs/gateway_config.yaml' \
  \) 2>/dev/null | sort -u
}

MODE=${1:-}
shift || true

case "${MODE}" in
  true)
    MODE="enable-placeholder"
    ;;
  false)
    MODE="disable"
    ;;
esac

ENDPOINT=""
TOKEN=""
CONFIG_FILES=()

case "${MODE}" in
  enable)
    ENDPOINT=${1:?endpoint required for enable}
    TOKEN=${2:?token required for enable}
    shift 2
    CONFIG_FILES=("$@")
    ;;
  enable-placeholder|disable)
    CONFIG_FILES=("$@")
    ;;
  *)
    echo "Usage: $0 enable <endpoint> <token> [config.yaml ...]" >&2
    echo "       $0 enable-placeholder [config.yaml ...]" >&2
    echo "       $0 disable [config.yaml ...]" >&2
    exit 1
    ;;
esac

if [ "${#CONFIG_FILES[@]}" -eq 0 ]; then
  mapfile -t CONFIG_FILES < <(discover_otel_agent_configs)
fi

if [ "${#CONFIG_FILES[@]}" -eq 0 ]; then
  echo "No OTel agent config files found to patch." >&2
  exit 1
fi

for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
  [ -f "${CONFIG_FILE}" ] || continue

  python3 - "${MODE}" "${ENDPOINT}" "${TOKEN}" "${CONFIG_FILE}" <<'PY'
import pathlib
import re
import sys

mode = sys.argv[1]
endpoint = sys.argv[2]
token = sys.argv[3]
path = pathlib.Path(sys.argv[4])

if mode == "enable":
    opamp_block = f"""  # OPAMP_SPLUNK_ENT_START
  opamp:
    server:
      http:
        endpoint: {endpoint}
        tls:
          insecure_skip_verify: true
        headers:
          Authorization: Bearer {token}
  # OPAMP_SPLUNK_ENT_END"""
elif mode == "enable-placeholder":
    opamp_block = """  # OPAMP_SPLUNK_ENT_START
  opamp:
    server:
      http:
        endpoint: ${SPLUNK_ENT_OPAMP_ENDPOINT}
        tls:
          insecure_skip_verify: true
        headers:
          Authorization: Bearer ${SPLUNK_ENT_OPAMP_TOKEN}
  # OPAMP_SPLUNK_ENT_END"""
else:
    opamp_block = ""

text = path.read_text()
start = "  # OPAMP_SPLUNK_ENT_START"
end = "  # OPAMP_SPLUNK_ENT_END"
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)

if mode in ("enable", "enable-placeholder"):
    if pattern.search(text):
        text = pattern.sub(opamp_block + "\n", text)
    else:
        anchor = "  opamp/splunk_o11y:"
        if anchor in text:
            ext_anchor = text.find(anchor)
            zpages_idx = text.find("\n  zpages:", ext_anchor)
            if zpages_idx != -1:
                text = text[: zpages_idx + 1] + opamp_block + "\n" + text[zpages_idx + 1 :]
            else:
                text = text[:ext_anchor] + opamp_block + "\n" + text[ext_anchor:]
        else:
            anchor = "extensions:"
            idx = text.index(anchor)
            insert_at = text.find("\n", idx) + 1
            text = text[:insert_at] + opamp_block + "\n" + text[insert_at:]

    service_section = text.split("service:", 1)[-1]
    if not re.search(r"^  - opamp\s*$", service_section, re.M):
        if "  - opamp/splunk_o11y\n" in text:
            text = re.sub(
                r"(  - opamp/splunk_o11y\n)",
                r"\1  - opamp\n",
                text,
                count=1,
            )
        elif re.search(r"^  extensions:\n", service_section, re.M):
            text = re.sub(
                r"(^service:\n(?:  .+\n)*?  extensions:\n)",
                r"\1  - opamp\n",
                text,
                count=1,
                flags=re.M,
            )
else:
    text = pattern.sub("", text)
    text = re.sub(r"^  - opamp\n", "", text, flags=re.M)

path.write_text(text)
PY

  chown splunk:splunk "${CONFIG_FILE}" 2>/dev/null || true
  echo "Patched ${CONFIG_FILE}"
done
