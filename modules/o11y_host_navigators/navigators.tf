resource "null_resource" "navigator" {
  for_each = local.os_configs

  triggers = {
    display_name           = each.value.navigator_name
    os_type                = each.value.os_type
    display_label          = each.value.display_name
    aggregate_dashboard_id = signalfx_dashboard.hosts[each.key].id
    instance_dashboard_id  = signalfx_dashboard.host[each.key].id
    api_url                = var.api_url
    api_admin_token        = var.api_admin_token
    script_hash            = filemd5("${path.module}/../../scripts/o11y_navigator.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
python3 "${path.module}/../../scripts/o11y_navigator.py" apply \
  --api-url '${var.api_url}' \
  --display-name '${each.value.navigator_name}' \
  --os-type '${each.value.os_type}' \
  --display-label '${each.value.display_name}' \
  --aggregate-dashboard-id '${signalfx_dashboard.hosts[each.key].id}' \
  --instance-dashboard-id '${signalfx_dashboard.host[each.key].id}'
EOT

    environment = {
      SPLUNK_ACCESS_TOKEN = var.api_admin_token
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = <<-EOT
python3 "${path.module}/../../scripts/o11y_navigator.py" destroy \
  --api-url '${self.triggers.api_url}' \
  --display-name '${self.triggers.display_name}'
EOT

    environment = {
      SPLUNK_ACCESS_TOKEN = self.triggers.api_admin_token
    }
  }

  depends_on = [
    signalfx_dashboard.hosts,
    signalfx_dashboard.host,
  ]
}
