resource "aws_instance" "rocky" {
  count                     = var.rocky_count
  ami                       = var.rocky_ami
  instance_type             = var.rocky_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  root_block_device {
    volume_size = 16
    volume_type = "gp2"
  }
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  tags = {
    Name = lower(join("-",[var.environment, "rocky", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder_rocky.sh"
    destination = "/tmp/install_splunk_universal_forwarder_rocky.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_httpd_rocky.sh"
    destination = "/tmp/install_httpd_rocky.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo yum update -y",

    ## Install httpd
      "sudo chmod +x /tmp/install_httpd_rocky.sh",
      "sudo /tmp/install_httpd_rocky.sh",

    ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME_RPM=${var.universalforwarder_filename_rpm}",
      "UNIVERSAL_FORWARDER_URL_RPM=${var.universalforwarder_url_rpm}",
      "PASSWORD=${var.splunk_admin_pwd}",
      var.splunk_ent_count == "1" ? "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}" : "echo skipping",
      "PRIVATE_DNS=${self.private_dns}",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME_RPM > /tmp/UNIVERSAL_FORWARDER_FILENAME_RPM",
      "echo $UNIVERSAL_FORWARDER_URL_RPM > /tmp/UNIVERSAL_FORWARDER_URL_RPM",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",
      "echo $PRIVATE_DNS > /tmp/PRIVATE_DNS",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder_rocky.sh",
      var.splunk_ent_count == "1" ? "/tmp/install_splunk_universal_forwarder_rocky.sh $UNIVERSAL_FORWARDER_FILENAME_RPM $UNIVERSAL_FORWARDER_URL_RPM $PASSWORD $SPLUNK_IP $PRIVATE_DNS" : "echo skipping"
    ]
  }

  connection {
    host = self.public_ip
    port = 22
    type = "ssh"
    user = "rocky"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "rocky_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.rocky.*.tags.Name,
    aws_instance.rocky.*.public_ip,
  )
}