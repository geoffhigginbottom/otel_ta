#! /bin/bash
# Version 2.0

PASSWORD=$1
ENVIRONMENT=$2
ACCESSTOKEN=$3
REALM=$4


#Setup Splunk_TA_nix
/opt/splunk/bin/splunk add index osnixsec -auth admin:$PASSWORD

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_nix/local/inputs.conf
[monitor:///var/log/auth.log]
disabled = 0
index = osnixsec
sourcetype = linux_secure
EOF

chown splunk:splunk /opt/splunk/etc/deployment-apps/Splunk_TA_nix/local/inputs.conf

cat << EOF > /opt/splunk/etc/system/local/serverclass.conf
[serverClass:Linux Hosts:app:Splunk_TA_nix]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Linux Hosts]
machineTypesFilter = linux-x86_64
whitelist.0 = $ENVIRONMENT*
EOF

chown splunk:splunk /opt/splunk/etc/system/local/serverclass.conf

# /opt/splunk/bin/splunk reload deploy-server


#Setup Splunk_TA_otel
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel/local/access_token
$ACCESSTOKEN
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel/local/realm
$REALM
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel/local/sapm-endpoint
"https://ingest.$REALM.signalfx.com/v2/trace"
EOF

chown splunk:splunk /opt/splunk/etc/deployment-apps/Splunk_TA_otel/local/*

/opt/splunk/bin/splunk reload deploy-server