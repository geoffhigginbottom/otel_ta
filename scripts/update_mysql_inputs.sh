#!/bin/bash

# Define file to be updated
FILE="/opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/inputs.conf"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found!"
    exit 1
fi

# Check if two arguments are provided
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <mysql_user> <mysql_pwd>"
    exit 1
fi

python3 - "$FILE" "$1" "$2" << 'EOF'
import re
import sys
import urllib.parse

file_path, mysql_user, mysql_pwd = sys.argv[1], sys.argv[2], sys.argv[3]
encoded_pwd = urllib.parse.quote(mysql_pwd, safe='')

with open(file_path) as f:
    lines = f.readlines()

new_lines = []
updated = False
for line in lines:
    if re.match(r'^mysql_user\s*=', line) or re.match(r'^mysql_pwd\s*=', line):
        continue
    match = re.match(r'^splunk_collector_env_vars\s*=\s*(.*)$', line)
    if match:
        current = match.group(1).strip()
        parts = [
            p for p in current.split(',')
            if p and not p.startswith('MYSQL_USERNAME=') and not p.startswith('MYSQL_PASSWORD=')
        ]
        parts.append(f'MYSQL_USERNAME={mysql_user}')
        parts.append(f'MYSQL_PASSWORD={encoded_pwd}')
        new_lines.append(f'splunk_collector_env_vars = {",".join(parts)}\n')
        updated = True
    else:
        new_lines.append(line)

if not updated:
    result = []
    inserted = False
    for line in new_lines:
        result.append(line)
        if not inserted and re.match(r'^splunk_config\s*=', line):
            result.append(f'splunk_collector_env_vars = MYSQL_USERNAME={mysql_user},MYSQL_PASSWORD={encoded_pwd}\n')
            inserted = True
    if not inserted:
        result.append(f'splunk_collector_env_vars = MYSQL_USERNAME={mysql_user},MYSQL_PASSWORD={encoded_pwd}\n')
    new_lines = result

with open(file_path, 'w') as f:
    f.writelines(new_lines)
EOF

echo "Updated splunk_collector_env_vars with MYSQL_USERNAME and MYSQL_PASSWORD in $FILE."

exit 0
