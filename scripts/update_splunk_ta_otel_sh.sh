#!/bin/bash

# Define the file to be updated
FILE="/opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/linux_x86_64/bin/Splunk_TA_otel.sh"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found!"
    exit 1
fi

# define MySQL variables to be added
HAS_MYSQL_USER_VAR="mysql_user_name=\"mysql_user\"\nmysql_user_value=\"\""
HAS_MYSQL_PWD_VAR="mysql_pwd_name=\"mysql_pwd\"\nmysql_pwd_value=\"\""

# Add MySQL variables
if ! grep -q "mysql_user_name=\"mysql_user\"" "$FILE"; then
    sed -i "/splunk_access_token_file_value=\"\"/a $HAS_MYSQL_USER_VAR" "$FILE"
    echo "Added mysql_user variable definitions."
else
    echo "mysql_user variable definitions already exists. No changes made"
fi

if ! grep -q "mysql_pwd_name=\"mysql_pwd\"" "$FILE"; then
    sed -i "/mysql_user_value=\"\"/a $HAS_MYSQL_PWD_VAR" "$FILE"
    echo "Added mysql_pwd variable definitions."
else
    echo "mysql_pwd variable definitions already exists. No changes made"
fi

# Define the MySQL Logic Blocks to be added
HAS_MYSQL_USER_LOGIC_BLOCK="\        fi\n\n        has_mysql_user=\"\$(echo \"\$line\" | grep \"\$mysql_user_name\")\"\n        if [ \"\$has_mysql_user\" ] ; then\n            splunk_TA_otel_log_msg \"DEBUG\" \"reading \$mysql_user_name from line \$has_mysql_user\"\n            mysql_user_value=\"\$(echo \"\$has_mysql_user\" | grep -Eo \">(.*?)<\" | sed 's/^>\\\(.*\\\)<$/\\\1/')\"\n            splunk_TA_otel_log_msg \"INFO\" \"Set \$mysql_user_name to \$mysql_user_value\""
HAS_MYSQL_PWD_LOGIC_BLOCK="\        fi\n\n        has_mysql_pwd=\"\$(echo \"\$line\" | grep \"\$mysql_pwd_name\")\"\n        if [ \"\$has_mysql_pwd\" ] ; then\n            splunk_TA_otel_log_msg \"DEBUG\" \"reading \$mysql_pwd_name from line \$has_mysql_pwd\"\n            mysql_pwd_value=\"\$(echo \"\$has_mysql_pwd\" | grep -Eo \">(.*?)<\" | sed 's/^>\\\(.*\\\)<$/\\\1/')\"\n            splunk_TA_otel_log_msg \"INFO\" \"Set \$mysql_pwd_name to \$mysql_pwd_value\""

# Add MySQL User Logic Block
if ! grep -q "has_mysql_user" "$FILE"; then
    # Insert the new block after the full line containing 'splunk_TA_otel_log_msg "INFO" "Set $splunk_realm_name to $splunk_realm_value"'
    sed -i "/splunk_TA_otel_log_msg \"INFO\" \"Set \$splunk_realm_name to \$splunk_realm_value\"/a $HAS_MYSQL_USER_LOGIC_BLOCK" "$FILE"
    echo "Added has_mysql_user logic block."
else
    echo "has_mysql_user logic block already exists. No changes made"
fi

# Add MySQL User PWD Logic Block
if ! grep -q "has_mysql_pwd" "$FILE"; then
    # Insert the new block after the full line containing 'splunk_TA_otel_log_msg "INFO" "Set $mysql_user_name to $mysql_user_value"'
    sed -i "/splunk_TA_otel_log_msg \"INFO\" \"Set \$mysql_user_name to \$mysql_user_value\"/a $HAS_MYSQL_PWD_LOGIC_BLOCK" "$FILE"
    echo "Added has_mysql_pwd logic block."
else
    echo "has_mysql_pwd logic block already exists. No changes made"
fi

# Define MySQL Code Blocks to be added
MYSQL_USER_CODE_BLOCK="\    fi\n    if [ \"\$mysql_user_value\" ] ; then\n      export MYSQL_USER=\"\$mysql_user_value\"\n    else\n      splunk_TA_otel_log_msg \"DEBUG\" \"NOT SET: \$mysql_user_name\""
MYSQL_PWD_CODE_BLOCK="\    fi\n    if [ \"\$mysql_pwd_value\" ] ; then\n      export MYSQL_PWD=\"\$mysql_pwd_value\"\n    else\n      splunk_TA_otel_log_msg \"DEBUG\" \"NOT SET: \$mysql_pwd_name\""

# Add MySQL User Code Block
if ! grep -q "export MYSQL_USER" "$FILE"; then
    sed -i "/splunk_TA_otel_log_msg \"DEBUG\" \"NOT SET: \$splunk_realm_name\"/a $MYSQL_USER_CODE_BLOCK" "$FILE"
    echo "Added mysql_user_name code block"
else
    echo "mysql_user_name code block alread exists. No changes made"
fi

# Add MySQL User Pwd Code Block
if ! grep -q "export MYSQL_PWD" "$FILE"; then
    sed -i "/splunk_TA_otel_log_msg \"DEBUG\" \"NOT SET: \$mysql_user_name\"/a $MYSQL_PWD_CODE_BLOCK" "$FILE"
    echo "Added mysql_pwd_name code block"
else
    echo "mysql_pwd_name code block alread exists. No changes made"
fi

echo "File '$FILE' has been updated successfully."

exit 0