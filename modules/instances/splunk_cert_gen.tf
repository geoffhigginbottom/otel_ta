resource "null_resource" "splunk_cert_gen" {
  count = var.splunk_ent_count != 0 ? 1 : 0

  depends_on = [aws_instance.splunk_ent, aws_eip_association.eip_assoc]

  triggers = {
    certs_script_hash                 = filemd5("${path.root}/scripts/certs.sh")
    enable_script_hash                = filemd5("${path.root}/scripts/enable_splunk_ent_otel_management.sh")
    finalize_script_hash              = filemd5("${path.root}/scripts/finalize_otel_collector_management.sh")
    otel_collector_management_enabled = var.otel_collector_management_enabled
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.eip} \
      'aws s3 cp s3://${var.s3_bucket_name}/scripts/certs.sh /tmp/certs.sh && \
       aws s3 cp s3://${var.s3_bucket_name}/scripts/enable_splunk_ent_otel_management.sh /tmp/enable_splunk_ent_otel_management.sh && \
       aws s3 cp s3://${var.s3_bucket_name}/scripts/finalize_otel_collector_management.sh /tmp/finalize_otel_collector_management.sh && \
       aws s3 cp s3://${var.s3_bucket_name}/scripts/apply_splunk_ent_opamp_deployment_configs.sh /tmp/apply_splunk_ent_opamp_deployment_configs.sh && \
       aws s3 cp s3://${var.s3_bucket_name}/scripts/patch_otel_splunk_ent_opamp.sh /tmp/patch_otel_splunk_ent_opamp.sh && \
       sudo chmod +x /tmp/certs.sh /tmp/enable_splunk_ent_otel_management.sh /tmp/finalize_otel_collector_management.sh /tmp/apply_splunk_ent_opamp_deployment_configs.sh /tmp/patch_otel_splunk_ent_opamp.sh && \
       echo "sudo /tmp/certs.sh ${var.certpath} ${var.passphrase} ${var.fqdn} ${var.country} ${var.state} ${var.location} ${var.org} ${var.le_certpath} ${var.letsencrypt_email}" > /tmp/certs_gen_cmd.txt && \
       sudo /tmp/certs.sh "${var.certpath}" "${var.passphrase}" "${var.fqdn}" "${var.country}" "${var.state}" "${var.location}" "${var.org}" "${var.le_certpath}" "${var.letsencrypt_email}"'
    EOT
  }
}
