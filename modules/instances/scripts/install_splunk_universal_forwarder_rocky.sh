#! /bin/bash
# Version 4.0

UNIVERSAL_FORWARDER_FILENAME=$1
UNIVERSAL_FORWARDER_URL=$2
PASSWORD=$3
SPLUNK_IP=$4

# Check if wget is installed, if not, install it
if ! command -v wget &> /dev/null
then
    echo "wget could not be found, installing wget"
    sudo yum install -y wget
fi

# Download the universal forwarder package using wget or curl
if command -v wget &> /dev/null
then
    wget -O $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL
else
    curl -o $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL
fi

# Install the universal forwarder package
sudo rpm -i $UNIVERSAL_FORWARDER_FILENAME

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
