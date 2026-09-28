#! /bin/bash
# Version 2.5 - Added LetsEncrypt Certificate Generation and Integration for Splunk Web and HEC
set -euo pipefail

## Variables ##
SLOC_CERTPATH=$1
PASSPHRASE=$2
FQDN=$3
COUNTRY=$4
STATE=$5
LOCATION=$6
ORG=$7
LE_CERTPATH=$8
LETSENCRYPT_EMAIL=$9

if [ -z "$8" ]; then
    echo "Usage: $0 <sloc_certpath> <passphrase> <fqdn> <country> <state> <location> <org> <le_certpath> [letsencrypt_email]"
    exit 1
fi

if [ -z "$LETSENCRYPT_EMAIL" ]; then
    LETSENCRYPT_EMAIL="admin@${FQDN}"
fi

SPLUNK="/opt/splunk/bin/splunk"
SPLUNK_USER_OPTS="--accept-license --answer-yes --no-prompt"

if [ "$(id -u)" -ne 0 ]; then
    echo "certs.sh must run as root (use sudo)." >&2
    exit 1
fi

SYSTEMCTL=/usr/bin/systemctl

splunk_systemd_unit() {
    if [ -f /etc/systemd/system/Splunkd.service ] && grep -q '^\[Unit\]' /etc/systemd/system/Splunkd.service; then
        echo "Splunkd"
    elif [ -f /etc/systemd/system/splunk.service ] && grep -q '^\[Unit\]' /etc/systemd/system/splunk.service; then
        echo "splunk"
    fi
}

splunk_managed_by_systemd() {
    [ -n "$(splunk_systemd_unit)" ]
}

fix_splunk_ownership() {
    /usr/bin/chown -R splunk:splunk /opt/splunk
    /usr/bin/find /opt/splunk/etc/system/local -type f -name '*.conf' -exec chmod 600 {} + 2>/dev/null || true
    /usr/bin/find /opt/splunk/var/run -type f -exec chown splunk:splunk {} + 2>/dev/null || true
}

splunkd_running() {
    pgrep -x splunkd >/dev/null 2>&1
}

port_bound() {
    local port=$1
    ss -tln 2>/dev/null | grep -q ":${port} "
}

remove_invalid_splunkd_unit() {
    if [ -f /etc/systemd/system/Splunkd.service ] && ! grep -q '^\[Unit\]' /etc/systemd/system/Splunkd.service; then
        echo "Removing invalid Splunkd.service unit file..."
        rm -f /etc/systemd/system/Splunkd.service
        "${SYSTEMCTL}" daemon-reload
    fi
}

ensure_splunk_limits_dropin() {
    if ! grep -q '^\[Unit\]' /etc/systemd/system/Splunkd.service 2>/dev/null; then
        return 0
    fi

    mkdir -p /etc/systemd/system/Splunkd.service.d
    cat > /etc/systemd/system/Splunkd.service.d/limits.conf <<EOF
[Service]
LimitNOFILE=64000
LimitNPROC=16000
LimitDATA=16000000000
LimitFSIZE=infinity
TasksMax=8192
EOF
    "${SYSTEMCTL}" daemon-reload
}

stop_splunk() {
    echo "Stopping Splunk..."
    local unit
    unit=$(splunk_systemd_unit || true)

    if [ -n "${unit}" ]; then
        "${SYSTEMCTL}" stop "${unit}" 2>/dev/null || true
    else
        sudo -u splunk "$SPLUNK" stop $SPLUNK_USER_OPTS 2>/dev/null || true
    fi

    for _ in $(seq 1 30); do
        splunkd_running || break
        sleep 2
    done

    if splunkd_running; then
        echo "Force-stopping remaining splunkd processes..."
        pkill -x splunkd 2>/dev/null || true
        sleep 2
        if [ -n "${unit}" ]; then
            "${SYSTEMCTL}" stop "${unit}" 2>/dev/null || true
        fi
    fi

    fix_splunk_ownership

    for port in 80 8000 8089; do
        for _ in $(seq 1 30); do
            port_bound "${port}" || break
            sleep 1
        done
        if port_bound "${port}"; then
            echo "Warning: port ${port} still appears to be in use after stopping Splunk."
        fi
    done
}

start_splunk_service() {
    local unit
    unit=$(splunk_systemd_unit || true)

    remove_invalid_splunkd_unit
    fix_splunk_ownership
    ensure_splunk_limits_dropin
    "${SYSTEMCTL}" daemon-reload
    "${SYSTEMCTL}" reset-failed Splunkd splunk 2>/dev/null || true

    if [ -n "${unit}" ]; then
        echo "Starting Splunk via systemctl (${unit})..."
        if ! "${SYSTEMCTL}" start "${unit}"; then
            echo "systemctl start ${unit} failed:" >&2
            "${SYSTEMCTL}" status "${unit}" --no-pager >&2 || true
            return 1
        fi
    else
        echo "Starting Splunk via splunk CLI (non-systemd)..."
        sudo -u splunk "$SPLUNK" start $SPLUNK_USER_OPTS
    fi
}

restart_splunk() {
    echo "Restarting Splunk to apply changes..."
    local unit
    unit=$(splunk_systemd_unit || true)

    remove_invalid_splunkd_unit
    fix_splunk_ownership
    ensure_splunk_limits_dropin
    "${SYSTEMCTL}" daemon-reload
    "${SYSTEMCTL}" reset-failed Splunkd splunk 2>/dev/null || true

    if [ -n "${unit}" ]; then
        echo "Restarting Splunk via systemctl (${unit})..."
        if splunkd_running || port_bound 8089; then
            if ! "${SYSTEMCTL}" restart "${unit}"; then
                echo "systemctl restart ${unit} failed, trying start..." >&2
                "${SYSTEMCTL}" start "${unit}" || return 1
            fi
        else
            if ! "${SYSTEMCTL}" start "${unit}"; then
                echo "systemctl start ${unit} failed:" >&2
                "${SYSTEMCTL}" status "${unit}" --no-pager >&2 || true
                return 1
            fi
        fi
    else
        echo "Restarting Splunk via splunk CLI (non-systemd)..."
        sudo -u splunk "$SPLUNK" restart $SPLUNK_USER_OPTS
    fi

    wait_splunk_ready
}

wait_splunk_ready() {
    local password=""
    if [ -f /tmp/splunk_password ]; then
        password=$(tr -d '\n' < /tmp/splunk_password)
    fi

    echo "Waiting for Splunk (8089/8000) to become ready..."
    for _ in $(seq 1 60); do
        if port_bound 8089; then
            if [ -n "${password}" ] && curl -skf -u "admin:${password}" https://localhost:8089/services/server/info >/dev/null 2>&1; then
                if port_bound 8000; then
                    echo "Splunk management API and web port are ready."
                    return 0
                fi
            elif [ -z "${password}" ] && sudo -u splunk "$SPLUNK" status 2>/dev/null | grep -qi 'splunkd is running'; then
                return 0
            fi
        fi
        sleep 5
    done

    echo "ERROR: Splunk did not become ready after restart." >&2
    "${SYSTEMCTL}" status Splunkd --no-pager 2>/dev/null || "${SYSTEMCTL}" status splunk --no-pager 2>/dev/null || true
    sudo -u splunk "$SPLUNK" status 2>/dev/null || true
    return 1
}

apply_server_ssl_config() {
    if ! grep -q '^\[sslConfig\]' "/opt/splunk/etc/system/local/server.conf" 2>/dev/null; then
        printf '\n[sslConfig]\n' >> "/opt/splunk/etc/system/local/server.conf"
    fi

    /usr/bin/sed -i '/serverCert =/d' "/opt/splunk/etc/system/local/server.conf"
    /usr/bin/sed -i '/sslRootCAPath =/d' "/opt/splunk/etc/system/local/server.conf"
    /usr/bin/sed -i '/sslPassword =/d' "/opt/splunk/etc/system/local/server.conf"
    /usr/bin/sed -i "/\[sslConfig\]/a serverCert = $SLOC_CERTPATH/myFinalCert.pem\nsslRootCAPath = $SLOC_CERTPATH/myCABundle.pem\nenableSplunkdSSL = true" "/opt/splunk/etc/system/local/server.conf"
    fix_splunk_ownership
}

should_enable_otel_collector_management() {
    if [ -f /tmp/otel_collector_management_enabled ]; then
        [ "$(tr -d '\n' < /tmp/otel_collector_management_enabled)" = "true" ]
    else
        return 0
    fi
}

ensure_otel_collector_management_conf() {
    local conf="/opt/splunk/etc/system/local/server.conf"
    mkdir -p /opt/splunk/etc/system/local

    if ! grep -q '^\[data_management\]' "${conf}" 2>/dev/null; then
        printf '\n[data_management]\n' >> "${conf}"
    fi

    if grep -q '^otel_collector_management_enabled' "${conf}"; then
        sed -i 's/^otel_collector_management_enabled.*/otel_collector_management_enabled = true/' "${conf}"
    else
        sed -i '/^\[data_management\]/a otel_collector_management_enabled = true' "${conf}"
    fi

    fix_splunk_ownership
    echo "Enabled otel_collector_management_enabled in server.conf (requires restart)."
}

## CREATE CERT CHAIN FOR SPLUNK LOG OBSERVER CONNECT / SPLUNK INTERCOMMUNICATIONS ##
# LetsEncrypt Certs do not support Subject Alternative Name (SAN) with 127.0.0.1 or localhost, which is required for LOC and Splunk intercommunications.
# So we have to create a Self Signed CA and Server Certificate.
# Starting splunk 10.2.0 kvstore forces the use of the cert listed in [sslConfig] and cannot be overridden in server.conf.

# Create directory and set ownership
/usr/bin/mkdir -p "$SLOC_CERTPATH"
/usr/bin/chown splunk:splunk "$SLOC_CERTPATH"

## Generate Root CA ##
echo "Generating Root CA..."
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -aes256 -passout pass:"$PASSPHRASE" -out "$SLOC_CERTPATH/myCAPrivateKey.key" 2048

# Create Extension Config
cat > "$SLOC_CERTPATH/ssl-extensions-x509.cnf" <<EOF
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_server]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$FQDN
EOF
chown splunk:splunk "$SLOC_CERTPATH/ssl-extensions-x509.cnf"

# Create CA CSR and Self-Sign
sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$SLOC_CERTPATH/myCAPrivateKey.key" -out "$SLOC_CERTPATH/myCACertificate.csr" -passin pass:"$PASSPHRASE" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=MyCustomCA"

sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$SLOC_CERTPATH/myCACertificate.csr" -signkey "$SLOC_CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -extensions v3_ca -extfile "$SLOC_CERTPATH/ssl-extensions-x509.cnf" -out "$SLOC_CERTPATH/myCACertificate.pem" -days 3650

## Generate Server Key and Certificate ##
echo "Generating Server Certificate..."
# Generate Server Key (Unencrypted for Splunk compatibility)
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -out "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" 2048

sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" -out "$SLOC_CERTPATH/mySplunkWebCert.csr" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"

# Sign Server Cert with the CA
sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$SLOC_CERTPATH/mySplunkWebCert.csr" -CA "$SLOC_CERTPATH/myCACertificate.pem" -CAkey "$SLOC_CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -CAcreateserial -extensions v3_server -extfile "$SLOC_CERTPATH/ssl-extensions-x509.cnf" -out "$SLOC_CERTPATH/mySplunkWebCert.pem" -days 1095

## Combine into Final PEM (CORRECT ORDER) ##
echo "Creating myFinalCert.pem..."
# Order: [Server Cert] [Private Key] [CA Chain]
/usr/bin/cat "$SLOC_CERTPATH/mySplunkWebCert.pem" "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" "$SLOC_CERTPATH/myCACertificate.pem" > "$SLOC_CERTPATH/myFinalCert.pem"

# Create the CA Bundle for trust (Custom CA + Splunk Apps CA)
/usr/bin/cp "$SLOC_CERTPATH/myCACertificate.pem" "$SLOC_CERTPATH/myCABundle.pem"
/usr/bin/cat /opt/splunk/etc/auth/appsCA.pem >> "$SLOC_CERTPATH/myCABundle.pem"

## Update Permissions ##
/usr/bin/chown -R splunk:splunk "$SLOC_CERTPATH"
/usr/bin/chmod 600 "$SLOC_CERTPATH"/*.pem
/usr/bin/chmod 600 "$SLOC_CERTPATH"/*.key

## Create copy in /tmp for easy access for setting up Log Observer Connect
cp "$SLOC_CERTPATH/mySplunkWebCert.pem" /tmp/mySplunkWebCert.pem
chown ubuntu:ubuntu /tmp/mySplunkWebCert.pem



## CREATE CERT CHAIN FOR WEB AND HEC USING LetsEncrypt ##
# To enable integrations such as ThousandEyes, we need a valid cert for HEC so are using LetsEncrypt.
# We will use the same cert for Splunk Web to keep things simple, but you could use the self signed for Splunk Web and LetsEncrypt for HEC if you wanted to avoid cert renewals impacting Splunk Web.
# LetsEncrypt Certs only last for 90 days. These environments are unlikely to be up for 90 days so this is not a problem.
# However running terraform again with tfa -replace="module.instances.null_resource.splunk_cert_gen[0]" will trigger regeneration of the certs if they have expired.

echo "Setting up LetsEncrypt integration..."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y certbot

echo "Stopping Splunk to free port 80 for certbot standalone validation..."
stop_splunk
apply_server_ssl_config

certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$LETSENCRYPT_EMAIL" \
    --no-eff-email \
    -d "$FQDN"

echo "Let's Encrypt setup complete."

# Create directory and set ownership
/usr/bin/mkdir -p "$LE_CERTPATH"
/usr/bin/chown splunk:splunk "$LE_CERTPATH"

## Copy the certs for use with Splunk Web ##
cp "/etc/letsencrypt/live/$FQDN/privkey.pem" "$LE_CERTPATH/"
cp "/etc/letsencrypt/live/$FQDN/fullchain.pem" "$LE_CERTPATH/"

## Create Chain for HEC ##
cat "/etc/letsencrypt/live/$FQDN/privkey.pem" "/etc/letsencrypt/live/$FQDN/fullchain.pem" > "$LE_CERTPATH/splunk_hec_combined.pem"

## Update Permissions ##
/usr/bin/chown -R splunk:splunk "$LE_CERTPATH"
/usr/bin/chmod 600 "$LE_CERTPATH/"*.pem



## Secure Splunk Web ##
# Cleanup old settings
/usr/bin/sed -i '/sslPassword =/d' "/opt/splunk/etc/system/local/web.conf"
/usr/bin/sed -i '/privKeyPath =/d' "/opt/splunk/etc/system/local/web.conf"
/usr/bin/sed -i '/caCertPath =/d' "/opt/splunk/etc/system/local/web.conf"
/usr/bin/sed -i '/serverCert =/d' "/opt/splunk/etc/system/local/web.conf"
/usr/bin/sed -i '/enableSplunkWebSSL =/d' "/opt/splunk/etc/system/local/web.conf"
/usr/bin/sed -i '/^httpport =/d' "/opt/splunk/etc/system/local/web.conf"

# LE certs enable HTTPS on Splunk Web on port 8000 (use https:// in the browser)
/usr/bin/sed -i "/\[settings\]/a enableSplunkWebSSL = true\nhttpport = 8000\nprivKeyPath = $LE_CERTPATH/privkey.pem\nserverCert = $LE_CERTPATH/fullchain.pem" "/opt/splunk/etc/system/local/web.conf"
fix_splunk_ownership



## Secure HEC ##
### Create the file if it does not exist
if [ ! -f /opt/splunk/etc/system/local/inputs.conf ]; then
    touch /opt/splunk/etc/system/local/inputs.conf
    /usr/bin/chown -R splunk:splunk /opt/splunk/etc/system/local/inputs.conf
    /usr/bin/chmod 600 /opt/splunk/etc/system/local/inputs.conf
fi

### Ensure the [http] stanza exists
if ! grep -q "^\[http\]" /opt/splunk/etc/system/local/inputs.conf; then
    echo -e "\n[http]" | tee -a /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'port'
if grep -q "^port =" /opt/splunk/etc/system/local/inputs.conf; then
    sed -i "s|^port =.*|port = 8088|" /opt/splunk/etc/system/local/inputs.conf
else
    sed -i "/^\[http\]/a port = 8088" /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'serverCert'
if grep -q "^serverCert =" /opt/splunk/etc/system/local/inputs.conf; then
    sed -i "s|^serverCert =.*|serverCert = $LE_CERTPATH/splunk_hec_combined.pem|" /opt/splunk/etc/system/local/inputs.conf
else
    sed -i "/^\[http\]/a serverCert = $LE_CERTPATH/splunk_hec_combined.pem" /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'enableSSL'
if grep -q "^enableSSL =" /opt/splunk/etc/system/local/inputs.conf; then
    sed -i "s|^enableSSL =.*|enableSSL = 1|" /opt/splunk/etc/system/local/inputs.conf
else
    sed -i "/^\[http\]/a enableSSL = 1" /opt/splunk/etc/system/local/inputs.conf
fi

echo "Splunk inputs.conf has been updated."

fix_splunk_ownership

if [ -f /tmp/splunk_password ]; then
    SPLUNK_PASSWORD=$(tr -d '\n' < /tmp/splunk_password)
    sudo -u splunk "$SPLUNK" enable web-ssl -auth "admin:${SPLUNK_PASSWORD}" || true
    fix_splunk_ownership
fi

if should_enable_otel_collector_management; then
    ensure_otel_collector_management_conf
fi

restart_splunk

if should_enable_otel_collector_management \
    && [ -f /tmp/splunk_password ] \
    && [ -f /tmp/splunk_private_ip ]; then
    SPLUNK_PASSWORD=$(tr -d '\n' < /tmp/splunk_password)
    SPLUNK_PRIVATE_IP=$(tr -d '\n' < /tmp/splunk_private_ip)
    chmod +x /tmp/finalize_otel_collector_management.sh /tmp/enable_splunk_ent_otel_management.sh
    /tmp/finalize_otel_collector_management.sh "${SPLUNK_PASSWORD}" "${SPLUNK_PRIVATE_IP}"
fi
