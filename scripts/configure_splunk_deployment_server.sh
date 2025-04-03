#! /bin/bash
# Version 2.0

PASSWORD=$1
ENVIRONMENT=$2
ACCESSTOKEN=$3
REALM=$4

########## Setup Splunk_TA_nix ##########
/opt/splunk/bin/splunk add index osnixsec -auth admin:$PASSWORD

mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_nix/local/

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_nix/local/inputs.conf
[monitor:///var/log/auth.log]
disabled = 0
index = osnixsec
sourcetype = linux_secure
EOF

chown splunk:splunk /opt/splunk/etc/deployment-apps/Splunk_TA_nix/local/inputs.conf
########## Setup Splunk_TA_nix ##########

########## Setup Splunk_TA_otel_base_x ##########
mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/local/
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled = true
start_by_shell=false
interval = 30
splunk_api_url=https://api.$REALM.signalfx.com
splunk_ingest_url=https://ingest.$REALM.signalfx.com
splunk_trace_url=https://ingest.$REALM.signalfx.com/v2/trace
splunk_listen_interface=localhost
splunk_realm=$REALM
splunk_gateway_url=172.32.2.100
EOF

mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_windows/local/
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_windows/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled = true
start_by_shell=false
interval = 30
splunk_api_url=https://api.$REALM.signalfx.com
splunk_ingest_url=https://ingest.$REALM.signalfx.com
splunk_trace_url=https://ingest.$REALM.signalfx.com/v2/trace
splunk_listen_interface=localhost
splunk_realm=$REALM
splunk_gateway_url=172.32.2.100
EOF
########## End Setup Splunk_TA_otel_base ##########



########## Setup Splunk_TA_otel_apps_gateway ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_gateway/local/access_token
# splunk_access_token_file=\$SPLUNK_OTEL_TA_HOME/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_gateway/configs/gateway_config.yaml
# splunk_config=\$SPLUNK_OTEL_TA_HOME/configs/gateway_config.yaml
splunk_listen_interface=0.0.0.0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_gateway ##########



########## Setup Splunk_TA_otel_apps_mysql ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql/local/access_token
# splunk_access_token_file=\$SPLUNK_OTEL_TA_HOME/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql/configs/mysql-otel-for-ta.yaml
# splunk_config=\$SPLUNK_OTEL_TA_HOME/configs/mysql-otel-for-ta.yaml

mysql_user=
mysql_pwd=

[monitor:///var/log/mysql/query.log]
index = mysql
sourcetype = mysql:generalQueryLog
disabled = 0

[monitor:///var/log/mysql/mysql-slow.log]
index = mysql
sourcetype = mysql:slowQueryLog
disabled = 0

[monitor:///var/log/mysql/error.log]
index = mysql
sourcetype = mysql:errorLog
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_mysql ##########

########## Setup Splunk_TA_otel_apps_mysql_gw ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql_gw/local/access_token
# splunk_access_token_file=\$SPLUNK_OTEL_TA_HOME/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql_gw/configs/mysql-gw-otel-for-ta.yaml
# splunk_config=\$SPLUNK_OTEL_TA_HOME/configs/mysql-gw-otel-for-ta.yaml

mysql_user=
mysql_pwd=

[monitor:///var/log/mysql/query.log]
index = mysql
sourcetype = mysql:generalQueryLog
disabled = 0

[monitor:///var/log/mysql/mysql-slow.log]
index = mysql
sourcetype = mysql:slowQueryLog
disabled = 0

[monitor:///var/log/mysql/error.log]
index = mysql
sourcetype = mysql:errorLog
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_mysql_gw ##########

########## Setup Splunk_TA_otel_apps_apache ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache/configs/apache-otel-for-ta.yaml
discovery=true

[monitor:///var/log/apache2]
index=apache2
sourcetype = access_combined
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_apache ##########

########## Setup Splunk_TA_otel_apps_apache_gw ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache_gw/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache_gw/configs/apache-gw-otel-for-ta.yaml

[monitor:///var/log/apache2]
index=apache2
sourcetype = access_combined
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_apache_gw ##########




########## Setup Splunk_TA_otel_apps_rocky ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_rocky/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_rocky/configs/rocky-otel-for-ta.yaml

[monitor:///var/log/httpd]
index=httpd
sourcetype = access_combined
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_rocky ##########



########## Setup Splunk_TA_otel_apps_ms_sql ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_ms_sql/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_ms_sql/configs/ms-sql-otel-for-ta.yaml
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_ms_sql ##########



########## Setup Splunk_TA_otel_apps_ms_sql_gw ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_ms_sql_gw/local/access_token
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_ms_sql_gw/configs/ms-sql-gw-otel-for-ta.yaml
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/local/access_token
$ACCESSTOKEN
EOF
########## End Setup Splunk_TA_otel_apps_ms_sql_gw ##########



########## Setup Splunk_UF_logs_to_deployment_server ##########
# mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_logs_to_deployment_server/
# mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_logs_to_deployment_server/local

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_UF_logs_to_deployment_server/local/outputs.conf
[tcpout]
defaultGroup = splunk_ent

[tcpout:splunk_ent]
server = 172.32.2.10:9997

[tcpout-server://172.32.2.10:9997]
EOF
########## End Splunk_UF_logs_to_deployment_server ##########

########## Setup Splunk_UF_windows_logs ##########
mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_Windows_Logs/
mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_Windows_Logs/local

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_UF_Windows_Logs/local/inputs.conf
[WinEventLog://Application]
disabled = 0
start_from = oldest
sourcetype = ApplicationLogs

[WinEventLog://Security]
disabled = 0
start_from = oldest
sourcetype = SecurityLogs

[WinEventLog://System]
disabled = 0
start_from = oldest
sourcetype = SystemLogs
EOF
########## End Splunk_UF_windows_logs ##########

########## Setup Serverclasses ##########
cat << EOF > /opt/splunk/etc/system/local/serverclass.conf

## Choice of sending logs to Splunk Cloud or to the Deployment Server 
# [serverClass:UF:app:100_iae-us0_splunkcloud]
# restartSplunkWeb = 0
# restartSplunkd = 1
# stateOnClient = enabled

# [serverClass:UF]
# machineTypesFilter = linux-x86_64,windows-x64
# whitelist.0 = *

[serverClass:Splunk-UF-logs-to-deployment-server:app:Splunk_UF_logs_to_deployment_server]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Splunk-UF-logs-to-deployment-server]
whitelist.0 = *

[serverClass:Splunk-UF-windows-logs:app:Splunk_UF_Windows_Logs]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Splunk-UF-windows-logs]
machineTypesFilter = windows-x64
whitelist.0 = *

[serverClass:Linux Hosts:app:Splunk_TA_nix]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Linux Hosts]
machineTypesFilter = linux-x86_64
whitelist.0 = *

[serverClass:OTEL-Base-Linux:app:Splunk_TA_otel_base_linux]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Base-Linux]
machineTypesFilter = linux-x86_64
whitelist.0 = *

[serverClass:OTEL-Base-Windows:app:Splunk_TA_otel_base_windows]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Base-Windows]
machineTypesFilter = windows-x64
whitelist.0 = *

[serverClass:OTEL-MySql:app:Splunk_TA_otel_apps_mysql]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MySql]
machineTypesFilter = linux-x86_64
whitelist.0 = *mysql*
blacklist.0 = *gw*

[serverClass:OTEL-Apache:app:Splunk_TA_otel_apps_apache]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Apache]
machineTypesFilter = linux-x86_64
whitelist.0 = *apache*
blacklist.0 = *gw*



[serverClass:OTEL-Rocky:app:Splunk_TA_otel_apps_rocky]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Rocky]
machineTypesFilter = linux-x86_64
whitelist.0 = *rocky*
blacklist.0 = *gw*



[serverClass:OTEL-MSSql:app:Splunk_TA_otel_apps_ms_sql]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MSSql]
machineTypesFilter = windows-x64
whitelist.0 = *ms-sql*
blacklist.0 = *gw*


[serverClass:OTEL-GW:app:Splunk_TA_otel_apps_gateway]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-GW]
machineTypesFilter = linux-x86_64
whitelist.0 = *gateway*


[serverClass:OTEL-MSSql-GW:app:Splunk_TA_otel_apps_ms_sql_gw]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MSSql-GW]
machineTypesFilter = windows-x64
whitelist.0 = *ms-sql-gw*


[serverClass:OTEL-MySql-GW:app:Splunk_TA_otel_apps_mysql_gw]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MySql-GW]
machineTypesFilter = linux-x86_64
whitelist.0 = *mysql-gw*

[serverClass:OTEL-Apache-GW:app:Splunk_TA_otel_apps_apache_gw]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Apache-GW]
machineTypesFilter = linux-x86_64
whitelist.0 = *apache-gw*

EOF

chown splunk:splunk /opt/splunk/etc/system/local/serverclass.conf
########## Setup Serverclasses ##########