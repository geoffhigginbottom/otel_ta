resource "aws_instance" "proxied_apache_web" {
  count                     = var.proxied_apache_web_count
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnet_ids, count.index)
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.proxied_instances_sg.id]

  tags = {
    Name = lower(join("-",[var.environment, "proxied-apache", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
 
  provisioner "file" {
    source      = "${path.module}/scripts/install_apache_web_server.sh"
    destination = "/tmp/install_apache_web_server.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/service-proxy.conf"
    destination = "/tmp/service-proxy.conf"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder.sh"
    destination = "/tmp/install_splunk_universal_forwarder.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/locust.service"
    destination = "/tmp/locust.service"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/locustfile.py"
    destination = "/tmp/locustfile.py"
  }

  provisioner "remote-exec" {
    inline = [
    ## Update Env Vars - Set Proxy
      "sudo sed -i '$ a http_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080/' /etc/environment",
      "sudo sed -i '$ a https_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080/' /etc/environment",
      "sudo sed -i '$ a no_proxy=169.254.169.254' /etc/environment",
      "sudo source /etc/environment",

    ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",

    ## Apply Updates
      "sudo apt-get update",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
   
    ## Install Apache
      "sudo chmod +x /tmp/install_apache_web_server.sh",
      "sudo /tmp/install_apache_web_server.sh",

    # Setup LoadGen Tools
      "sudo apt-get -y install python3-pip",

    ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}",
      "UNIVERSAL_FORWARDER_URL=${var.universalforwarder_url}",
      # "PASSWORD=${random_string.apache_universalforwarder_password.result}",
      "PASSWORD=${var.splunk_admin_pwd}",
      var.splunk_ent_count == "1" ? "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}" : "echo skipping",
      "PRIVATE_DNS=${self.private_dns}",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME",
      "echo $UNIVERSAL_FORWARDER_URL > /tmp/UNIVERSAL_FORWARDER_URL",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",
      "echo $PRIVATE_DNS > /tmp/PRIVATE_DNS",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder.sh",
      var.splunk_ent_count == "1" ? "http_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080 https_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080 /tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL $PASSWORD $SPLUNK_IP $PRIVATE_DNS" : "echo skipping",

    ## Run Locust
      "sudo apt-get -y install python3-pip",
      "sudo pip3 install locust",
      "sudo chmod +x /tmp/locustfile.py",
      "sudo chmod +x /tmp/locust.service",
      "sudo mv /tmp/locustfile.py /home/ubuntu/locustfile.py",
      "sudo mv /tmp/locust.service /etc/systemd/system/locust.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl restart locust",
    ]
  }

  connection {
    host = self.public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "proxied_apache_web_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.proxied_apache_web.*.tags.Name,
    aws_instance.proxied_apache_web.*.public_ip,
    aws_instance.proxied_apache_web.*.private_dns,
  )
}