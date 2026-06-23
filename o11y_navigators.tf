variable "o11y_navigators_enabled" {
  description = "Deploy Splunk O11y Linux and Windows host navigator dashboards."
  type        = bool
  default     = true
}

module "o11y_host_navigators" {
  count  = var.o11y_navigators_enabled ? 1 : 0
  source = "./modules/o11y_host_navigators"

  api_url         = var.api_url
  api_admin_token = local.splunk_api_admin_token
}

output "o11y_linux_navigator_name" {
  description = "Linux navigator tile name on Infrastructure > Overview."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].linux_navigator_name : null
}

output "o11y_windows_navigator_name" {
  description = "Windows navigator tile name on Infrastructure > Overview."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].windows_navigator_name : null
}

output "o11y_linux_hosts_dashboard_id" {
  description = "Splunk O11y dashboard ID for aggregated Linux host metrics."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].linux_hosts_dashboard_id : null
}

output "o11y_linux_host_dashboard_id" {
  description = "Splunk O11y dashboard ID for single Linux host drill-down."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].linux_host_dashboard_id : null
}

output "o11y_windows_hosts_dashboard_id" {
  description = "Splunk O11y dashboard ID for aggregated Windows host metrics."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].windows_hosts_dashboard_id : null
}

output "o11y_windows_host_dashboard_id" {
  description = "Splunk O11y dashboard ID for single Windows host drill-down."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].windows_host_dashboard_id : null
}

output "o11y_navigator_metadata" {
  description = "Navigator tile metadata for Infrastructure > Overview."
  value       = var.o11y_navigators_enabled ? module.o11y_host_navigators[0].navigator_metadata : null
}
