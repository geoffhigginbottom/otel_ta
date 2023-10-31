[Splunk_TA_otel://<name>]

splunk_access_token_file = <value>
* File whose contents store the credentials to be set in `SPLUNK_ACCESS_TOKEN` (used to auth with Splunk Observability Cloud, default `$SPLUNK_OTEL_TA_HOME/local/access_token`).

splunk_otel_log_file = <value>
* Log file for otel collector


# Below are all "pass through" configuration options that will enable environment variables supported in 
# https://github.com/signalfx/splunk-otel-collector/blob/main/internal/settings/settings.go#L37-L64
splunk_api_url = <value>
* Splunk Observability realm to use for the `SPLUNK_API_URL` environment variable

splunk_ballast_size_mib = <value>
* Splunk Observability realm to use for the `SPLUNK_BALLAST_SIZE_MIB` environment variable

splunk_bundle_dir = <value>
* Splunk Observability realm to use for the `SPLUNK_BUNDLE_DIR` environment variable (used in smart agent config, default `$SPLUNK_OTEL_TA_PLATFORM_HOME/bin/agent-bundle`)

splunk_collectd_dir = <value>
* Splunk Observability realm to use for the `SPLUNK_COLLECTD_DIR` environment variable (used in smart agent config, default `$SPLUNK_OTEL_TA_HOME/bin/agent-bundle/run/collectd`)

splunk_config = <value>
* Splunk Observability realm to use for the `SPLUNK_CONFIG` environment variable (default `$SPLUNK_OTEL_TA_HOME/config/ta_agent_config.yaml`)

splunk_config_dir = <value>
* Splunk Observability realm to use for the `SPLUNK_CONFIG_DIR` environment variable (default `$SPLUNK_OTEL_TA_HOME/config/`)

splunk_debug_config_server = <value>
* Splunk Observability realm to use for the `SPLUNK_DEBUG_CONFIG_SERVER` environment variable

splunk_config_yaml = <value>
* Splunk Observability realm to use for the `SPLUNK_CONFIG_YAML` environment variable

splunk_listen_interface = <value>
* Splunk Observability realm to use for the `SPLUNK_LISTEN_INTERFACE` environment variable

splunk_memory_limit_mib = <value>
* Splunk Observability realm to use for the `SPLUNK_MEMORY_LIMIT_MIB` environment variable

splunk_total_mib = <value>
* Splunk Observability realm to use for the `SPLUNK_MEMORY_TOTAL_MIB` environment variable

splunk_trace_url = <value>
* Endpoint for `SPLUNK_TRACE_URL`

splunk_ingest_url = <value>
* Endpoint for `SPLUNK_API_URL`

splunk_realm = <value>
* Splunk Observability realm to use for the `SPLUNK_REALM` environment variable (ex us0)