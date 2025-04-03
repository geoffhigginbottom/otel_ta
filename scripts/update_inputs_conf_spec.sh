#!/bin/bash

# Define file to be updated
FILE="/opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/README/inputs.conf.spec"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found!"
    exit 1
fi

# Define MySql specs to add
MYSQL_USER="\nmysql_user = <value>\n* Value for mysql user account for OTel Agent"
MYSQL_PWD="\nmysql_pwd = <value>\n* Value for mysql user pwd for OTel Agent"

# Add mysql_user spec
if ! grep -q "mysql_user = <value>" "$FILE"; then
    echo -e "$MYSQL_USER" >> "$FILE"
    echo "Added mysql_user spec."
else
    echo "mysql_user already exists. No changes made."
fi

# Add mysql_pwd spec
if ! grep -q "mysql_pwd = <value>" "$FILE"; then
    echo -e "$MYSQL_PWD" >> "$FILE"
    echo "Added mysql_pwd spec."
else
    echo "mysql_pwd already exists. No changes made."
fi

echo "File '$FILE' has been updated successfully."

exit 0