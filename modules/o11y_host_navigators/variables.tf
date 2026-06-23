variable "time_range" {
  description = "Default time range for host dashboards."
  type        = string
  default     = "-3h"
}

variable "api_url" {
  description = "Splunk Observability API URL (same value as the signalfx provider api_url)."
  type        = string
}

variable "api_admin_token" {
  description = "Splunk Observability admin API token for navigator creation."
  type        = string
  sensitive   = true
}
