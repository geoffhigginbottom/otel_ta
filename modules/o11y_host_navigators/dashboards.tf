resource "signalfx_dashboard" "hosts" {
  for_each = local.os_configs

  name            = each.value.hosts_dashboard
  description     = "Host table and fleet charts for ${each.value.display_name} OTel hosts."
  dashboard_group = signalfx_dashboard_group.host_overview[each.key].id
  time_range      = var.time_range

  chart {
    chart_id = signalfx_table_chart.active_hosts[each.key].id
    row      = 0
    column   = 0
    width    = 12
    height   = 4
  }

  dynamic "chart" {
    for_each = {
      for idx, id in sort([
        for metric_id, metric in local.aggregate_heatmap_items :
        metric_id if metric.os_key == each.key
      ]) : id => idx
    }

    content {
      chart_id = signalfx_heatmap_chart.aggregate[chart.key].id
      row      = 2
      column   = chart.value * 3
      width    = 3
      height   = 2
    }
  }

  dynamic "chart" {
    for_each = [
      for id in sort(keys(local.aggregate_trend_items)) :
      local.aggregate_trend_items[id]
      if local.aggregate_trend_items[id].os_key == each.key
    ]

    content {
      chart_id = signalfx_time_chart.aggregate_trend[chart.value.id].id
      row      = local.aggregate_trend_layout[chart.value.id].row
      column   = local.aggregate_trend_layout[chart.value.id].column
      width    = 4
      height   = 2
    }
  }
}

resource "signalfx_dashboard" "host" {
  for_each = local.os_configs

  name            = each.value.host_dashboard
  description     = "Single-host drill-down for ${each.value.display_name}. Opened from the navigator when a host is selected."
  dashboard_group = signalfx_dashboard_group.host_overview[each.key].id
  time_range      = var.time_range

  variable {
    property = "host.name"
    alias    = "host"
  }

  dynamic "chart" {
    for_each = [
      for id in sort(keys(local.instance_items)) :
      local.instance_items[id]
      if local.instance_items[id].os_key == each.key
    ]

    content {
      chart_id = signalfx_time_chart.instance[chart.value.id].id
      row      = local.instance_layout[chart.value.id].row
      column   = local.instance_layout[chart.value.id].column
      width    = 4
      height   = 2
    }
  }
}
