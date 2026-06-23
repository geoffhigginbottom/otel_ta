locals {
  primary_metric_keys = toset(["cpu", "memory", "disk", "network"])

  common_host_metrics = [
    {
      key    = "cpu"
      metric = "cpu.utilization"
      label  = "CPU Utilization"
    },
    {
      key    = "memory"
      metric = "memory.utilization"
      label  = "Memory Utilization"
    },
    {
      key    = "disk"
      metric = "disk.utilization"
      label  = "Disk Utilization"
    },
    {
      key    = "network"
      metric = "network.total"
      label  = "Network I/O"
    },
    {
      key    = "disk_ops"
      metric = "disk_ops.total"
      label  = "Disk Operations"
    },
    {
      key    = "paging_in"
      metric = "vmpage_io.memory.in"
      label  = "Paging In"
    },
    {
      key    = "paging_out"
      metric = "vmpage_io.memory.out"
      label  = "Paging Out"
    },
  ]

  linux_metrics = concat(local.common_host_metrics, [
    {
      key    = "load_1m"
      metric = "system.cpu.load_average.1m"
      label  = "Load Average (1m)"
    },
    {
      key    = "load_5m"
      metric = "system.cpu.load_average.5m"
      label  = "Load Average (5m)"
    },
    {
      key    = "load_15m"
      metric = "system.cpu.load_average.15m"
      label  = "Load Average (15m)"
    },
    {
      key    = "processes"
      metric = "system.processes.count"
      label  = "Process Count"
    },
  ])

  windows_metrics = concat(local.common_host_metrics, [
    {
      key    = "processor_time"
      metric = "processor.time"
      label  = "Processor Time"
    },
    {
      key    = "memory_committed"
      metric = "bytes.committed"
      label  = "Committed Bytes"
    },
    {
      key    = "processes"
      metric = "system.processes.count"
      label  = "Process Count"
    },
  ])

  os_configs = {
    linux = {
      os_type         = "linux"
      display_name    = "Linux"
      metrics         = local.linux_metrics
      navigator_name  = "Active Linux hosts (OTel)"
      hosts_dashboard = "Linux Hosts (OTel)"
      host_dashboard  = "Linux Host (OTel)"
    }
    windows = {
      os_type         = "windows"
      display_name    = "Windows"
      metrics         = local.windows_metrics
      navigator_name  = "Active Windows hosts (OTel)"
      hosts_dashboard = "Windows Hosts (OTel)"
      host_dashboard  = "Windows Host (OTel)"
    }
  }

  os_metric_items = {
    for os_key, os_cfg in local.os_configs :
    os_key => {
      for metric in os_cfg.metrics :
      metric.key => merge(metric, { os_key = os_key, os_type = os_cfg.os_type })
    }
  }

  aggregate_heatmap_items = {
    for item in flatten([
      for os_key, metrics in local.os_metric_items : [
        for key, metric in metrics : {
          id      = "${os_key}_${key}"
          os_key  = os_key
          os_type = metric.os_type
          metric  = metric.metric
          label   = metric.label
        } if contains(local.primary_metric_keys, key)
      ]
    ]) : item.id => item
  }

  aggregate_trend_items = {
    for item in flatten([
      for os_key, metrics in local.os_metric_items : [
        for key, metric in metrics : {
          id      = "${os_key}_${key}"
          os_key  = os_key
          os_type = metric.os_type
          metric  = metric.metric
          label   = metric.label
        } if !contains(local.primary_metric_keys, key)
      ]
    ]) : item.id => item
  }

  instance_items = {
    for item in flatten([
      for os_key, metrics in local.os_metric_items : [
        for key, metric in metrics : {
          id      = "${os_key}_${key}"
          os_key  = os_key
          os_type = metric.os_type
          metric  = metric.metric
          label   = metric.label
        }
      ]
    ]) : item.id => item
  }

  aggregate_trend_layout = {
    for layout in flatten([
      for os_key, os_cfg in local.os_configs : [
        for idx, id in sort([
          for metric_id, metric in local.aggregate_trend_items :
          metric_id if metric.os_key == os_key
        ]) : {
          id     = id
          row    = 4 + floor(idx / 3) * 2
          column = (idx % 3) * 4
        }
      ]
    ]) : layout.id => layout
  }

  instance_layout = {
    for layout in flatten([
      for os_key, os_cfg in local.os_configs : [
        for idx, id in sort([
          for metric_id, metric in local.instance_items :
          metric_id if metric.os_key == os_key
        ]) : {
          id     = id
          row    = floor(idx / 3) * 2
          column = (idx % 3) * 4
        }
      ]
    ]) : layout.id => layout
  }
}
