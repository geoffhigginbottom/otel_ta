#! /bin/bash
# Version 2.1

PASSWORD=$1
VERSION=$2
FILENAME=$3
LO_CONNECT_PASSWORD=$4
LICENSE_FILE=$5

SPLUNK=/opt/splunk/bin/splunk

# wget -O /tmp/$FILENAME "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=$VERSION&product=splunk&filename=$FILENAME&wget=true"
wget -O /tmp/$FILENAME "https://download.splunk.com/products/splunk/releases/$VERSION/linux/$FILENAME"
dpkg -i /tmp/$FILENAME

# First start creates admin credentials via --seed-passwd. Do not use REST user
# creation before start: Splunk 10.x Free/Trial lacks the Auth license feature.
$SPLUNK start --accept-license --answer-yes --no-prompt --seed-passwd $PASSWORD --run-as-root

# Apply Enterprise license before any Auth-dependent REST/CLI configuration.
mkdir -p /opt/splunk/etc/licenses/enterprise
cp "/tmp/$LICENSE_FILE" "/opt/splunk/etc/licenses/enterprise/${LICENSE_FILE}.lic"
$SPLUNK restart --accept-license --answer-yes --no-prompt --run-as-root

# Wait for management port before authenticated REST calls.
MAX_RETRIES=30
RETRY_COUNT=0
while ! curl -skf -u "admin:$PASSWORD" https://localhost:8089/services/server/info >/dev/null 2>&1 && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "Splunk management port did not become ready in time."
  exit 1
fi

$SPLUNK enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes --no-prompt
systemctl daemon-reload

#Enable Token Auth
curl -skf -u admin:$PASSWORD -X POST https://localhost:8089/services/admin/token-auth/tokens_auth -d disabled=false

#Enable Receiver
/opt/splunk/bin/splunk enable listen 9997 -auth admin:$PASSWORD

#Add LOC Role
curl -skf -u admin:$PASSWORD https://localhost:8089/services/admin/roles \
  -d name=lo_connect\
  -d srchIndexesAllowed=%2A \
  -d imported_roles=user \
  -d srchJobsQuota=12 \
  -d rtSrchJobsQuota=0 \
  -d cumulativeSrchJobsQuota=12 \
  -d cumulativeRTSrchJobsQuota=0 \
  -d srchTimeWin=2592000 \
  -d srchTimeEarliest=7776000 \
  -d srchDiskQuota=1000 \
  -d capabilities=edit_tokens_own

#Add LOC User
/opt/splunk/bin/splunk add user LO-Connect -role lo_connect -password $LO_CONNECT_PASSWORD -auth admin:$PASSWORD

#Add Indexs
# /opt/splunk/bin/splunk add index k8s-logs -auth admin:$PASSWORD
/opt/splunk/bin/splunk add index apache2 -auth admin:$PASSWORD
/opt/splunk/bin/splunk add index httpd -auth admin:$PASSWORD
/opt/splunk/bin/splunk add index mysql -auth admin:$PASSWORD

#Change webport to 8000 to avoid conflict with Splunk Offices WiFi Restrictons
/opt/splunk/bin/splunk set web-port 8000 -auth admin:$PASSWORD

#Enable HEC
/opt/splunk/bin/splunk http-event-collector enable -uri https://localhost:8089 -enable-ssl 0 -port 8088 -auth admin:$PASSWORD

#Create HEC Tokens
# /opt/splunk/bin/splunk http-event-collector create OTEL-K8S -uri https://localhost:8089 -description "Used by OTEL K8S" -disabled 0 -index k8s-logs -indexes k8s-logs -auth admin:$PASSWORD
/opt/splunk/bin/splunk http-event-collector create OTEL -uri https://localhost:8089 -description "Used by OTEL" -disabled 0 -index main -indexes main -auth admin:$PASSWORD

#Create systemd drop-in for ulimits (do not overwrite Splunkd.service created by enable boot-start)
#https://docs.splunk.com/Documentation/Splunk/latest/Troubleshooting/ulimitErrors
mkdir -p /etc/systemd/system/Splunkd.service.d
cat << EOF > /etc/systemd/system/Splunkd.service.d/limits.conf
[Service]
LimitNOFILE=64000
LimitNPROC=16000
LimitDATA=16000000000
LimitFSIZE=infinity
TasksMax=8192
EOF
systemctl daemon-reload

#Create /etc/systemd/system/disable-thp.service
#https://docs.splunk.com/Documentation/Splunk/latest/ReleaseNotes/SplunkandTHP
cat << EOF > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF

chown -R splunk:splunk /opt/splunk