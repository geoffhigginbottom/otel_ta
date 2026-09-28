#! /bin/bash
# Version 3.0 - Non-root Splunk service (splunk user + systemd)
set -euo pipefail

PASSWORD=$1
VERSION=$2
FILENAME=$3
LO_CONNECT_PASSWORD=$4
LICENSE_FILE=$5

SPLUNK=/opt/splunk/bin/splunk
S_CLI="sudo -u splunk ${SPLUNK}"

wget -O "/tmp/${FILENAME}" "https://download.splunk.com/products/splunk/releases/${VERSION}/linux/${FILENAME}"
dpkg -i "/tmp/${FILENAME}"

mkdir -p /opt/splunk/etc/licenses/enterprise
cp "/tmp/${LICENSE_FILE}" "/opt/splunk/etc/licenses/enterprise/${LICENSE_FILE}.lic"

mkdir -p /opt/splunk/etc/system/local
cat <<EOF > /opt/splunk/etc/system/local/user-seed.conf
[user_info]
USERNAME = admin
PASSWORD = ${PASSWORD}
EOF
echo "v1" > /opt/splunk/etc/splunk.license.accepted
touch /opt/splunk/ftr

chown -R splunk:splunk /opt/splunk

"${SPLUNK}" enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes --no-prompt
systemctl daemon-reload

mkdir -p /etc/systemd/system/Splunkd.service.d
cat <<EOF > /etc/systemd/system/Splunkd.service.d/limits.conf
[Service]
LimitNOFILE=64000
LimitNPROC=16000
LimitDATA=16000000000
LimitFSIZE=infinity
TasksMax=8192
EOF
systemctl daemon-reload

if systemctl list-unit-files Splunkd.service 2>/dev/null | grep -q '^Splunkd.service'; then
  systemctl enable Splunkd
  systemctl start Splunkd
elif systemctl list-unit-files splunk.service 2>/dev/null | grep -q '^splunk.service'; then
  systemctl enable splunk
  systemctl start splunk
else
  sudo -u splunk "${SPLUNK}" start --accept-license --answer-yes --no-prompt
fi

MAX_RETRIES=30
RETRY_COUNT=0
while ! curl -skf -u "admin:${PASSWORD}" https://localhost:8089/services/server/info >/dev/null 2>&1 && [ "${RETRY_COUNT}" -lt "${MAX_RETRIES}" ]; do
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
if [ "${RETRY_COUNT}" -eq "${MAX_RETRIES}" ]; then
  echo "Splunk management port did not become ready in time."
  exit 1
fi

rm -f /opt/splunk/etc/system/local/user-seed.conf
chown -R splunk:splunk /opt/splunk

curl -skf -u "admin:${PASSWORD}" -X POST https://localhost:8089/services/admin/token-auth/tokens_auth -d disabled=false

${S_CLI} enable listen 9997 -auth "admin:${PASSWORD}"

curl -skf -u "admin:${PASSWORD}" https://localhost:8089/services/admin/roles \
  -d name=lo_connect \
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

${S_CLI} add user LO-Connect -role lo_connect -password "${LO_CONNECT_PASSWORD}" -auth "admin:${PASSWORD}"

${S_CLI} add index apache2 -auth "admin:${PASSWORD}"
${S_CLI} add index httpd -auth "admin:${PASSWORD}"
${S_CLI} add index mysql -auth "admin:${PASSWORD}"

${S_CLI} set web-port 8000 -auth "admin:${PASSWORD}"

${S_CLI} http-event-collector enable -uri https://localhost:8089 -enable-ssl 0 -port 8088 -auth "admin:${PASSWORD}"
${S_CLI} http-event-collector create OTEL -uri https://localhost:8089 -description "Used by OTEL" -disabled 0 -index main -indexes main -auth "admin:${PASSWORD}"

cat <<EOF > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now disable-thp.service

chown -R splunk:splunk /opt/splunk
