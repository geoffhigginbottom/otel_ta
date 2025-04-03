#!/bin/bash

# Download and Install the Latest Updates for the OS
yum update -y
yum upgrade -y

# Set the Server Timezone to UTC
timedatectl set-timezone UTC

# Enable Firewalld and allow SSH & HTTP/S Ports
# systemctl start firewalld
# systemctl enable firewalld
# firewall-cmd --permanent --add-service=ssh
# firewall-cmd --permanent --add-service=http
# firewall-cmd --permanent --add-service=https
# firewall-cmd --reload

# Install Apache (httpd)
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create basic web page
echo "<h1>Apache Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html

# Enable mod_status in httpd.conf
cat <<EOL >> /etc/httpd/conf/httpd.conf

<IfModule mod_status.c>
    <Location /server-status>
        SetHandler server-status
        Require local
    </Location>
    ExtendedStatus On
</IfModule>
EOL

# Restart Apache to apply changes
systemctl restart httpd
