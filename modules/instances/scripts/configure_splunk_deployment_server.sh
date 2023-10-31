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

########## Setup Splunk_TA_otel_base ##########
mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/local/
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled = true
EOF

#### HACK TO FIX MISSING 'README/inputs.conf.spec' - REMOVE WHEN FIXED ####
mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/README
mv /tmp/inputs.conf.spec /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/README/inputs.conf.spec

########## Setup Splunk_TA_otel_base ##########

########## Setup Splunk_TA_otel_apps_mysql ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
start_by_shell=false
interval = 30
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql/local/access_token
splunk_api_url=https://api.$REALM.signalfx.com
splunk_ingest_url=https://ingest.$REALM.signalfx.com
splunk_trace_url=https://ingest.$REALM.signalfx.com/v2/trace
splunk_listen_interface=localhost
splunk_realm=$REALM
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_mysql/configs/mysql-otel-for-ta.yaml

[monitor:///var/log/mysql/query.log]
index = conftech-mysql
sourcetype = mysql:generalQueryLog
disabled = 0

[monitor:///var/log/mysql/mysql-slow.log]
index = conftech-mysql
sourcetype = mysql:slowQueryLog
disabled = 0

[monitor:///var/log/mysql/error.log]
index = conftech-mysql
sourcetype = mysql:errorLog
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local/access_token
$ACCESSTOKEN
EOF
########## Setup Splunk_TA_otel_apps_mysql ##########

########## Setup Splunk_TA_otel_apps_apache ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled=false
start_by_shell=false
interval = 30
splunk_access_token_file=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache/local/access_token
splunk_api_url=https://api.$REALM.signalfx.com
splunk_ingest_url=https://ingest.$REALM.signalfx.com
splunk_trace_url=https://ingest.$REALM.signalfx.com/v2/trace
splunk_listen_interface=localhost
splunk_realm=$REALM
splunk_config=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apps_apache/configs/apache-otel-for-ta.yaml

[monitor:///var/log/apache2]
index=conftech-apache2
sourcetype = access_combined
disabled = 0
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local/access_token
$ACCESSTOKEN
EOF
########## Setup Splunk_TA_otel_apps_apache ##########

########## Setup Serverclasses ##########
cat << EOF > /opt/splunk/etc/system/local/serverclass.conf
[serverClass:Linux Hosts:app:Splunk_TA_nix]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Linux Hosts]
machineTypesFilter = linux-x86_64
whitelist.0 = $ENVIRONMENT*

[serverClass:OTEL-Base:app:Splunk_TA_otel_base]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Base]
machineTypesFilter = linux-x86_64
whitelist.0 = $ENVIRONMENT*

[serverClass:OTEL-MySql:app:Splunk_TA_otel_apps_mysql]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MySql]
machineTypesFilter = linux-x86_64
whitelist.0 = *mysql*

[serverClass:OTEL-Apache:app:Splunk_TA_otel_apps_apache]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Apache]
machineTypesFilter = linux-x86_64
whitelist.0 = *apache*

[serverClass:UF:app:100_iae-us0_splunkcloud]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:UF]
machineTypesFilter = linux-x86_64
whitelist.0 = conftech*

EOF

chown splunk:splunk /opt/splunk/etc/system/local/serverclass.conf
########## Setup Serverclasses ##########

/opt/splunk/bin/splunk reload deploy-server -auth admin:$PASSWORD