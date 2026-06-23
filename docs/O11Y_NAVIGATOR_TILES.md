# Linux and Windows Host Navigator Tiles

Terraform deploys two Infrastructure navigator tiles plus host dashboards.

## Navigator tile names

After `terraform apply`, look on **Infrastructure > Overview** under **Hosts overview**:

| Navigator tile | OS filter |
|----------------|-----------|
| **Active Linux hosts (OTel)** | `os.type:linux` + `sf_metric:cpu.utilization` |
| **Active Windows hosts (OTel)** | `os.type:windows` + `sf_metric:cpu.utilization` |

Navigator tiles are registered with `POST /v2/navigator` by `scripts/o11y_navigator.py` during `terraform apply`.

### Table view (ArgoCD pattern)

Org navigators cannot set `visualizations` via the API (unlike built-in **Active hosts**). The working pattern matches a custom navigator such as **ArgoCD Apps**:

- `listColumns` with **property** columns only (no `metricClasses` / `metricColumns`)
- `defaultGroupBy: "none"`
- One primary `entityMetrics` entry; the **CPU utilization** column uses property `value`
- Entity properties for OS, memory size, and vCPU (`host_kernel_name`, `host_mem_total`, `host_logical_cpus`)
- Pinned filters on the navigator bar: `deployment.environment`, `host.name`, `host_kernel_release`, `host_cpu_model`

Reference payloads: `config_files/navigator_linux_hosts_otel.json` and `config_files/navigator_windows_hosts_otel.json`.

The **Linux Hosts (OTel)** / **Windows Hosts (OTel)** dashboards still include a table chart with CPU, Memory, and Disk % for full utilization metrics.

## Deploy

```bash
terraform apply
```

Uses `api_admin_token` (admin API scope). To skip:

```hcl
o11y_navigators_enabled = false
```

## Verify

```bash
terraform output o11y_navigator_metadata
curl -s -H "X-SF-TOKEN: $SPLUNK_ACCESS_TOKEN" \
  -H "Accept: application/vnd.splunk.observability.navigator+json" \
  "$API_URL/v2/navigator?displayName=Active%20Linux%20hosts%20(OTel)"
```
