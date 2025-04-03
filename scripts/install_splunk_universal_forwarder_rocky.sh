#! /bin/bash
# Version 4.0

UNIVERSAL_FORWARDER_FILENAME=$1
PASSWORD=$2
SPLUNK_IP=$3
AWS_PRIVATE_DNS=$4

# Install the universal forwarder package
sudo rpm -i /tmp/$UNIVERSAL_FORWARDER_FILENAME

# Set up the admin user
sudo /opt/splunkforwarder/bin/splunk cmd splunkd rest --noauth POST /services/authentication/users 'name=admin&password='"$PASSWORD"'&roles=admin'

# Start Splunk and accept the license
sudo /opt/splunkforwarder/bin/splunk start --accept-license

# Enable Splunk to start at boot
sudo /opt/splunkforwarder/bin/splunk enable boot-start

# Set the deployment server
sudo /opt/splunkforwarder/bin/splunk set deploy-poll $SPLUNK_IP:8089 -auth admin:$PASSWORD

# Restart Splunk
sudo /opt/splunkforwarder/bin/splunk restart

# Define FQDN as meta_data - need to test if we can do this before above restart
sudo touch /opt/splunkforwarder/etc/system/local/inputs.conf
echo -e "[default]\n_meta = host.name::$AWS_PRIVATE_DNS" | sudo tee /opt/splunkforwarder/etc/system/local/inputs.conf > /dev/null

# Restart Splunk
sudo /opt/splunkforwarder/bin/splunk restart