resource "null_resource" "splunk_cert_gen" {
  count = var.splunk_ent_count != 0 ? 1 : 0

  depends_on = [aws_instance.splunk_ent, aws_eip_association.eip_assoc]

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.eip} \
      'aws s3 cp s3://${var.s3_bucket_name}/scripts/certs.sh /tmp/certs.sh && \
       sudo chmod +x /tmp/certs.sh && \
       echo "sudo /tmp/certs.sh ${var.certpath} ${var.passphrase} ${var.fqdn} ${var.country} ${var.state} ${var.location} ${var.org} ${var.le_certpath} ${var.letsencrypt_email}" > /tmp/certs_gen_cmd.txt && \
       sudo /tmp/certs.sh "${var.certpath}" "${var.passphrase}" "${var.fqdn}" "${var.country}" "${var.state}" "${var.location}" "${var.org}" "${var.le_certpath}" "${var.letsencrypt_email}"'
    EOT
  }
}
