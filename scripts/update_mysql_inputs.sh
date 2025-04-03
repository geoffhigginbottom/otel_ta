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

# Update values in the file
sed -i "s/^mysql_user=.*/mysql_user=$1/" "$FILE"
sed -i "s/^mysql_pwd=.*/mysql_pwd=$2/" "$FILE"

echo "Updated mysql_user and mysql_pwd in $FILE."

exit 0