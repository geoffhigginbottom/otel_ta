resource "signalfx_dashboard_group" "host_overview" {
  for_each = local.os_configs

  name        = each.value.navigator_name
  description = "${each.value.display_name} OTel hosts. Host table with CPU, memory, and disk utilization appears on the ${each.value.hosts_dashboard} dashboard when this tile is selected on Infrastructure > Overview."

  import_qualifier {
    metric = "cpu.utilization"

    filters {
      property = "host.name"
      values   = ["*"]
    }

    filters {
      property = "os.type"
      values   = [each.value.os_type]
    }
  }
}

resource "signalfx_table_chart" "active_hosts" {
  for_each = local.os_configs

  name        = "Active ${each.value.display_name} Hosts"
  description = "Host table with CPU, memory, and disk utilization."

  program_text = <<-EOF
    cpu = data('cpu.utilization', filter=filter('os.type', '${each.value.os_type}')).mean(by=['host.name']).publish(label='CPU %')
    memory_used = data('system.memory.usage', filter=filter('state', 'used') and filter('os.type', '${each.value.os_type}')).sum(by=['host.name'])
    memory_total = data('system.memory.usage', filter=filter('state', 'used', 'free', 'cached', 'buffered') and filter('os.type', '${each.value.os_type}')).sum(by=['host.name'])
    memory = ((memory_used / memory_total) * 100).mean(by=['host.name']).publish(label='Memory %')
    disk = data('disk.utilization', filter=filter('os.type', '${each.value.os_type}')).mean(by=['host.name']).publish(label='Disk %')
  EOF

  group_by = ["host.name"]

  viz_options {
    label        = "CPU %"
    display_name = "CPU %"
  }

  viz_options {
    label        = "Memory %"
    display_name = "Memory %"
  }

  viz_options {
    label        = "Disk %"
    display_name = "Disk %"
  }
}

resource "signalfx_heatmap_chart" "aggregate" {
  for_each = local.aggregate_heatmap_items

  name        = "${local.os_configs[each.value.os_key].display_name} ${each.value.label}"
  description = "Compare ${each.value.label} across ${each.value.os_key} hosts."

  program_text = <<-EOF
    data('${each.value.metric}', filter=filter('os.type', '${each.value.os_type}')).publish(label='${each.value.label}')
  EOF

  group_by = ["host.name"]
  sort_by  = "+value"

  color_scale {
    gte   = 80
    color = "red"
  }

  color_scale {
    lt    = 80
    gte   = 50
    color = "yellow"
  }

  color_scale {
    lt    = 50
    color = "green"
  }
}

resource "signalfx_time_chart" "aggregate_trend" {
  for_each = local.aggregate_trend_items

  name        = "${local.os_configs[each.value.os_key].display_name} ${each.value.label}"
  description = "Per-host ${each.value.label} across the ${each.value.os_key} fleet."

  program_text = <<-EOF
    data('${each.value.metric}', filter=filter('os.type', '${each.value.os_type}')).mean(by=['host.name']).publish(label='${each.value.label}')
  EOF

  plot_type  = "LineChart"
  time_range = 3600

  viz_options {
    label = each.value.label
    axis  = "left"
  }
}

resource "signalfx_time_chart" "instance" {
  for_each = local.instance_items

  name        = "${local.os_configs[each.value.os_key].display_name} ${each.value.label}"
  description = "${each.value.label} for the selected ${each.value.os_key} host."

  program_text = <<-EOF
    data('${each.value.metric}', filter=filter('os.type', '${each.value.os_type}')).publish(label='${each.value.label}')
  EOF

  plot_type  = "LineChart"
  time_range = 3600

  viz_options {
    label = each.value.label
    axis  = "left"
  }
}
