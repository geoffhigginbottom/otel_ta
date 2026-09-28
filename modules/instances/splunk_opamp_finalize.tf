resource "null_resource" "splunk_opamp_finalize" {
  count = var.splunk_ent_count != 0 && var.otel_collector_management_enabled ? 1 : 0

  depends_on = [null_resource.splunk_cert_gen]

  triggers = {
    cert_gen_id          = null_resource.splunk_cert_gen[0].id
    enable_script_hash   = filemd5("${path.root}/scripts/enable_splunk_ent_otel_management.sh")
    finalize_script_hash = filemd5("${path.root}/scripts/finalize_otel_collector_management.sh")
    apply_script_hash    = filemd5("${path.root}/scripts/apply_splunk_ent_opamp_deployment_configs.sh")
    patch_script_hash    = filemd5("${path.root}/scripts/patch_otel_splunk_ent_opamp.sh")
    splunk_private_ip    = var.splunk_private_ip
    scripts_sync_id      = var.scripts_sync_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.eip} \
      'set -euo pipefail
       aws s3 cp s3://${var.s3_bucket_name}/scripts/enable_splunk_ent_otel_management.sh /tmp/enable_splunk_ent_otel_management.sh
       aws s3 cp s3://${var.s3_bucket_name}/scripts/finalize_otel_collector_management.sh /tmp/finalize_otel_collector_management.sh
       aws s3 cp s3://${var.s3_bucket_name}/scripts/apply_splunk_ent_opamp_deployment_configs.sh /tmp/apply_splunk_ent_opamp_deployment_configs.sh
       aws s3 cp s3://${var.s3_bucket_name}/scripts/patch_otel_splunk_ent_opamp.sh /tmp/patch_otel_splunk_ent_opamp.sh
       chmod +x /tmp/enable_splunk_ent_otel_management.sh /tmp/finalize_otel_collector_management.sh /tmp/apply_splunk_ent_opamp_deployment_configs.sh /tmp/patch_otel_splunk_ent_opamp.sh
       printf "%s\n" "${var.splunk_private_ip}" > /tmp/splunk_private_ip
       sudo /tmp/finalize_otel_collector_management.sh'
    EOT
  }
}
