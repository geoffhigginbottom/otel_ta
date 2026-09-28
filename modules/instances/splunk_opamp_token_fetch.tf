locals {
  splunk_ent_opamp_endpoint_default = "https://${var.splunk_private_ip}:8089/services/tenant/agent-management/v2/opamp/otel"
  splunk_opamp_fetch_script         = "${path.root}/scripts/fetch_splunk_opamp_token.sh"
}

resource "null_resource" "splunk_opamp_token_fetch" {
  count = var.splunk_ent_count != 0 && var.otel_collector_management_enabled ? 1 : 0

  depends_on = [null_resource.splunk_opamp_finalize]

  triggers = {
    finalize_id       = null_resource.splunk_opamp_finalize[0].id
    fetch_script_hash = filemd5(local.splunk_opamp_fetch_script)
  }

  provisioner "local-exec" {
    command = "bash ${local.splunk_opamp_fetch_script} ${var.private_key_path} ${var.eip} ${path.root}/.generated ${local.splunk_ent_opamp_endpoint_default}"
  }
}

output "splunk_ent_opamp_token" {
  value = try(
    (
      var.splunk_ent_count != 0 && var.otel_collector_management_enabled &&
      length(trimspace(file("${path.root}/.generated/splunk_ent_opamp_token"))) > 0
    ) ? trimspace(file("${path.root}/.generated/splunk_ent_opamp_token")) : null,
    null
  )
  sensitive = true
}

output "splunk_ent_opamp_endpoint" {
  value = try(
    (
      var.splunk_ent_count != 0 && var.otel_collector_management_enabled
      ) ? (
      length(trimspace(file("${path.root}/.generated/splunk_ent_opamp_endpoint"))) > 0
      ? trimspace(file("${path.root}/.generated/splunk_ent_opamp_endpoint"))
      : local.splunk_ent_opamp_endpoint_default
    ) : null,
    local.splunk_ent_opamp_endpoint_default
  )
}

output "splunk_ent_opamp_credentials" {
  value = try(
    (
      var.splunk_ent_count != 0 && var.otel_collector_management_enabled &&
      length(trimspace(file("${path.root}/.generated/splunk_ent_opamp_credentials.json"))) > 0
    ) ? jsondecode(file("${path.root}/.generated/splunk_ent_opamp_credentials.json")) : null,
    null
  )
  sensitive = true
}
