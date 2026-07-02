output "navigator_deployments" {
  description = "Per-OS settings for registering Infrastructure navigator tiles via API."
  value = {
    for os_key, cfg in local.os_configs :
    os_key => {
      display_name           = cfg.navigator_name
      os_type                = cfg.os_type
      display_label          = cfg.display_name
      aggregate_dashboard_id = signalfx_dashboard.hosts[os_key].id
      instance_dashboard_id  = signalfx_dashboard.host[os_key].id
    }
  }
}

output "linux_navigator_name" {
  description = "Navigator tile name on Infrastructure > Overview."
  value       = local.os_configs.linux.navigator_name
}

output "windows_navigator_name" {
  description = "Navigator tile name on Infrastructure > Overview."
  value       = local.os_configs.windows.navigator_name
}

output "linux_hosts_dashboard_id" {
  description = "Dashboard ID for aggregated Linux host metrics."
  value       = signalfx_dashboard.hosts["linux"].id
}

output "linux_host_dashboard_id" {
  description = "Dashboard ID for single Linux host drill-down."
  value       = signalfx_dashboard.host["linux"].id
}

output "windows_hosts_dashboard_id" {
  description = "Dashboard ID for aggregated Windows host metrics."
  value       = signalfx_dashboard.hosts["windows"].id
}

output "windows_host_dashboard_id" {
  description = "Dashboard ID for single Windows host drill-down."
  value       = signalfx_dashboard.host["windows"].id
}

output "dashboard_groups" {
  description = "Infrastructure > Overview dashboard group IDs keyed by operating system."
  value = {
    for os_key, group in signalfx_dashboard_group.host_overview :
    os_key => {
      id   = group.id
      name = group.name
    }
  }
}

output "navigator_metadata" {
  description = "Infrastructure tile and dashboard metadata deployed by this module."
  value = {
    for os_key, cfg in local.os_configs :
    os_key => {
      navigator_tile         = cfg.navigator_name
      category               = "Hosts overview"
      aggregated_dashboard   = cfg.hosts_dashboard
      instance_dashboard     = cfg.host_dashboard
      created_via            = "POST /v2/navigator"
      import_qualifiers      = "cpu.utilization (host.name = *) & (os.type = ${cfg.os_type})"
      host_table_dashboard   = cfg.hosts_dashboard
      host_table_note        = "CPU/Memory/Disk table chart on aggregated_dashboard (navigator table metrics require Splunk visualizations API)."
    }
  }
}
