#!/bin/bash
# Add or remove Splunk Enterprise OpAMP (agent management) settings in OTel YAML configs.
set -euo pipefail

ENABLED=${1:-false}
shift

for CONFIG_FILE in "$@"; do
  [ -f "${CONFIG_FILE}" ] || continue

  python3 - "${ENABLED}" "${CONFIG_FILE}" <<'PY'
import pathlib
import re
import sys

enabled = sys.argv[1].lower() == "true"
path = pathlib.Path(sys.argv[2])
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

text = path.read_text()
start = "  # OPAMP_SPLUNK_ENT_START"
end = "  # OPAMP_SPLUNK_ENT_END"
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)

if enabled:
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
        text = re.sub(
            r"(  - opamp/splunk_o11y\n)",
            r"\1  - opamp\n",
            text,
            count=1,
        )
else:
    text = pattern.sub("", text)
    text = re.sub(r"^  - opamp\n", "", text, flags=re.M)

path.write_text(text)
PY

  chown splunk:splunk "${CONFIG_FILE}" 2>/dev/null || true
done
