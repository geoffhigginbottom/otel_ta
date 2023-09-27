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
rm /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/default/inputs.conf
rm /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/configs/access_token
rm /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/configs/realm
rm /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/configs/sample-otel-for-ta.yaml
rm /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/configs/sapm-endpoint

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base/default/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
disabled = true
start_by_shell=false
EOF
########## Setup Splunk_TA_otel_base ##########

########## Setup Splunk_TA_otel_mysql ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
splunk_otel_config_location=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_mysql/configs/mysql-otel-for-ta.yaml
disabled=false
start_by_shell=false
#access_token_secret_name=access_token
#splunk_o11y_realm=$REALM
#splunk_o11y_sapm_endpoint=https://ingest.$REALM.signalfx.com/v2/trace

#[monitor://\$SPLUNK_HOME/var/log/splunk/otel.log]
#_TCP_ROUTING = *
#index = _internal

#[monitor://\$SPLUNK_HOME/var/log/splunk/Splunk_TA_otel.log]
#_TCP_ROUTING = *
#index = _internal
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/access_token
$ACCESSTOKEN
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/realm
$REALM
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/sapm-endpoint
"https://ingest.$REALM.signalfx.com/v2/trace"
EOF
########## Setup Splunk_TA_otel_mysql ##########

########## Setup Splunk_TA_otel_apache ##########
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apache/local/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel]
splunk_otel_config_location=\$SPLUNK_HOME/etc/apps/Splunk_TA_otel_apache/configs/apache-otel-for-ta.yaml
disabled=false
start_by_shell=false
#access_token_secret_name=access_token
#splunk_o11y_realm=$REALM
#splunk_o11y_sapm_endpoint=https://ingest.$REALM.signalfx.com/v2/trace

#[monitor://\$SPLUNK_HOME/var/log/splunk/otel.log]
#_TCP_ROUTING = *
#index = _internal

#[monitor://\$SPLUNK_HOME/var/log/splunk/Splunk_TA_otel.log]
#_TCP_ROUTING = *
#index = _internal
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apache/local/access_token
$ACCESSTOKEN
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apache/local/realm
$REALM
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apache/local/sapm-endpoint
"https://ingest.$REALM.signalfx.com/v2/trace"
EOF
########## Setup Splunk_TA_otel_apache ##########

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

[serverClass:OTEL-MySql:app:Splunk_TA_otel_mysql]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MySql]
machineTypesFilter = linux-x86_64
whitelist.0 = *mysql*

[serverClass:OTEL-Apache:app:Splunk_TA_otel_apache]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-Apache]
machineTypesFilter = linux-x86_64
whitelist.0 = *apache*
EOF

chown splunk:splunk /opt/splunk/etc/system/local/serverclass.conf
########## Setup Serverclasses ##########

/opt/splunk/bin/splunk reload deploy-server