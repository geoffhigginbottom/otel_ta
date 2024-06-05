resource "aws_instance" "gateway" {
  count                     = var.gateway_count
  ami                       = var.ami
  instance_type             = var.gateway_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  private_ip                = var.gw_private_ip
  root_block_device {
    volume_size = 16
    volume_type = "gp2"
  }
  key_name                  = var.key_name
  vpc_security_group_ids    = [
    aws_security_group.instances_sg.id
  ]

  tags = {
    Name = lower(join("-",[var.environment, "gateway", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder.sh"
    destination = "/tmp/install_splunk_universal_forwarder.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}",
      "UNIVERSAL_FORWARDER_URL=${var.universalforwarder_url}",
      "PASSWORD=${var.splunk_admin_pwd}",
      var.splunk_ent_count == "1" ? "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}" : "echo skipping",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME",
      "echo $UNIVERSAL_FORWARDER_URL > /tmp/UNIVERSAL_FORWARDER_URL",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder.sh",
      var.splunk_ent_count == "1" ? "/tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL $PASSWORD $SPLUNK_IP" : "echo skipping",
    ]
  }

  connection {
    host = self.public_ip
    port = 22
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "gateway_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.gateway.*.tags.Name,
    aws_instance.gateway.*.public_ip,
  )
}