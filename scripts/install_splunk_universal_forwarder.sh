#! /bin/bash
# Version 2.0

UNIVERSAL_FORWARDER_FILENAME=$1
PASSWORD=$2
SPLUNK_IP=$3
HOSTNAME=$4

sudo dpkg -i /tmp/$UNIVERSAL_FORWARDER_FILENAME
sudo /opt/splunkforwarder/bin/splunk cmd splunkd rest --noauth POST /services/authentication/users 'name=admin&password='"$PASSWORD"'&roles=admin'
sudo /opt/splunkforwarder/bin/splunk start --accept-license
sudo /opt/splunkforwarder/bin/splunk enable boot-start
sudo /opt/splunkforwarder/bin/splunk set deploy-poll $SPLUNK_IP:8089 -auth admin:$PASSWORD  # adds to /opt/splunkforwarder/etc/system/local/deploymentclient.conf
sudo /opt/splunkforwarder/bin/splunk restart

sudo touch /opt/splunkforwarder/etc/system/local/inputs.conf
echo -e "[default]\n_meta = host.name::$HOSTNAME" | sudo tee /opt/splunkforwarder/etc/system/local/inputs.conf > /dev/null

sudo /opt/splunkforwarder/bin/splunk restart