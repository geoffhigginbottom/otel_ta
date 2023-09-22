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

##################################


########## Setup Splunk_TA_otel ##########

mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel/local/

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

##################################



########## Setup Splunk_TA_otel_mysql ##########

### Default Files ###
mv /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/default/inputs.conf /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/default/inputs_orig.conf
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/default/inputs.conf
[Splunk_TA_otel://Splunk_TA_otel_mysql]
splunk_otel_config_location = $SPLUNK_HOME/etc/apps/Splunk_TA_otel_mysql/configs/mysql-otel-for-ta.yaml
disabled = false
start_by_shell=false
access_token_secret_name = access_token

[monitor://$SPLUNK_HOME/var/log/splunk/otel.log]
_TCP_ROUTING = *
index = _internal

[monitor://$SPLUNK_HOME/var/log/splunk/Splunk_TA_otel.log]
_TCP_ROUTING = *
index = _internal
EOF

### Local Files ###

mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/access_token
$ACCESSTOKEN
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/realm
$REALM
EOF

cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/local/sapm-endpoint
"https://ingest.$REALM.signalfx.com/v2/trace"
EOF


### Config Files ###
cat << EOF > /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/configs/mysql-otel-for-ta.yaml
config_sources:
  # see https://github.com/signalfx/splunk-otel-collector/tree/main/internal/configsource/includeconfigsource#configuration
  include/refreshable_credential:
    watch_files: true
  include/static:
receivers:
  hostmetrics:
    collection_interval: 5s
    scrapers:
      cpu:
      disk:
      filesystem:
      memory:
      network:
      # Paging/Swap space utilization and I/O metrics
      paging:
      # System load average metrics https://en.wikipedia.org/wiki/Load_(computing)
      load:
      # Aggregated system process count metrics
      processes:
      # System processes metrics, disabled by default
      # process:
  # Enables the otlp receiver with default settings
  #  - grpc (default endpoint = 0.0.0.0:4317)
  #  - http (default endpoint = 0.0.0.0:4318)
  # Full configuration here: https://github.com/open-telemetry/opentelemetry-collector/tree/main/receiver/otlpreceiver
  otlp:
    protocols:
      grpc:
        endpoint: localhost:4317
      http:
        endpoint: localhost:4318
  prometheus/internal:
    config:
      scrape_configs:
      - job_name: 'otel-collector'
        scrape_interval: 10s
        static_configs:
        - targets: ['0.0.0.0:8888']
        metric_relabel_configs:
          - source_labels: [ __name__ ]
            regex: '.*grpc_io.*'
            action: drop
  smartagent/mysql:
    type: collectd/mysql
    host: 127.0.0.1
    port: 3306
    databases:
      - name:
    username: signalfxagent
    password: P@ssword123

extensions:
  health_check:
  pprof:
  zpages:

processors:
  batch:
  memory_limiter:
    check_interval: 2s
    limit_mib: 500
  # Detect if the collector is running on a cloud system. Overrides resource attributes set by receivers.
  # Detector order is important: the `system` detector goes last so it can't preclude cloud detectors from setting host/os info.
  # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourcedetectionprocessor#ordering
  resourcedetection/metrics:
    detectors: [gcp, ecs, ec2, azure, system]
    override: true
  resourcedetection/traces:
    detectors: [gcp, ecs, ec2, azure, system]
    override: true
  resource/telemetry:
    attributes:
      - action: insert
        key: splunk.distribution
        value: otel-ta

exporters:
  signalfx:
    access_token: ${env:OBSERVABILITY_ACCESS_TOKEN}
    realm: ${include/refreshable_credential:$SPLUNK_HOME/etc/apps/Splunk_TA_otel/local/realm}
  logging: # for TA debugging
    loglevel: debug
  sapm:
    access_token: ${env:OBSERVABILITY_ACCESS_TOKEN}
    endpoint: ${include/static:$SPLUNK_HOME/etc/apps/Splunk_TA_otel/local/sapm-endpoint}

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    metrics:
      receivers: [hostmetrics, smartagent/mysql]
      processors: [memory_limiter, batch, resourcedetection/metrics]
      exporters: [signalfx]
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection/traces]
      exporters: [sapm]
    metrics/telemetry:
      receivers: [prometheus/internal]
      processors: [memory_limiter, batch, resourcedetection/metrics, resource/telemetry]
      exporters: [signalfx]
EOF

# chown -R 502:staff /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/
chown -R splunk:splunk /opt/splunk/etc/deployment-apps/Splunk_TA_otel_mysql/

### Setup Serverclasses ###
cat << EOF > /opt/splunk/etc/system/local/serverclass.conf
[serverClass:Linux Hosts:app:Splunk_TA_nix]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:Linux Hosts]
machineTypesFilter = linux-x86_64
whitelist.0 = $ENVIRONMENT*

[serverClass:OTEL:app:Splunk_TA_otel]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL]
machineTypesFilter = linux-x86_64
whitelist.0 = *apache*


[serverClass:OTEL-MySql:app:Splunk_TA_otel_mysql]
restartSplunkWeb = 0
restartSplunkd = 1
stateOnClient = enabled

[serverClass:OTEL-MySql]
machineTypesFilter = linux-x86_64
whitelist.0 = *mysql*
EOF

chown splunk:splunk /opt/splunk/etc/system/local/serverclass.conf

/opt/splunk/bin/splunk reload deploy-server