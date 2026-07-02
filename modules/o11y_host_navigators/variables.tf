variable "environment" {
  description = "Deployment environment name (e.g. dev, staging)."
  type        = string
}

variable "time_range" {
  description = "Default time range for host dashboards."
  type        = string
  default     = "-3h"
}
