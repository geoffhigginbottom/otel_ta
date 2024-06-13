## Replaced with a static password set in terraform.tfvars - easier for testing when re-deploying
# resource "random_string" "splunk_password" {
#   length           = 12
#   special          = false
#   # override_special = "@£$"
# }

resource "random_string" "lo_connect_password" {
  length           = 12
  special          = false
}

resource "aws_instance" "splunk_ent" {
  count                     = var.splunk_ent_count
  ami                       = var.ami
  instance_type             = var.splunk_ent_inst_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  private_ip                = var.splunk_private_ip
  root_block_device {
    volume_size = 32
    volume_type = "gp2"
  }
  key_name                  = var.key_name
  vpc_security_group_ids    = [
    aws_security_group.splunk_ent_sg.id,
  ]

  tags = {
    Name = lower(join("-",[var.environment, "splunk-ent", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_enterprise.sh"
    destination = "/tmp/install_splunk_enterprise.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/configure_splunk_deployment_server.sh"
    destination = "/tmp/configure_splunk_deployment_server.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/certs.sh"
    destination = "/tmp/certs.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/mysql-otel-for-ta.yaml"
    destination = "/tmp/mysql-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/mysql-gw-otel-for-ta.yaml"
    destination = "/tmp/mysql-gw-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/apache-otel-for-ta.yaml"
    destination = "/tmp/apache-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/rocky-otel-for-ta.yaml"
    destination = "/tmp/rocky-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/apache-gw-otel-for-ta.yaml"
    destination = "/tmp/apache-gw-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/ms-sql-otel-for-ta.yaml"
    destination = "/tmp/ms-sql-otel-for-ta.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/gateway_config.yaml"
    destination = "/tmp/gateway_config.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/inputs.conf.spec"
    destination = "/tmp/inputs.conf.spec"
  }

  provisioner "file" {
    source      = join("/",[var.splunk_enterprise_files_local_path, var.splunk_enterprise_license_filename])
    destination = "/tmp/${var.splunk_enterprise_license_filename}"
  }

  provisioner "file" {
    source      = join("/",[var.splunk_enterprise_files_local_path, var.splunk_enterprise_ta_linux_filename])
    destination = "/tmp/${var.splunk_enterprise_ta_linux_filename}"
  }

  provisioner "file" {
    source      = join("/",[var.splunk_enterprise_files_local_path, var.splunk_ta_otel_filename])
    destination = "/tmp/${var.splunk_ta_otel_filename}"
  }

  provisioner "file" {
    source      = join("/",[var.splunk_enterprise_files_local_path, var.config_explorer_filename])
    destination = "/tmp/${var.config_explorer_filename}"
  }

  ## disabled to enable logs to be sent direct to deployment server indexer instead of this cloud instance
  # provisioner "file" {
  #   source      = join("/",[var.splunk_enterprise_files_local_path, var.splunk_cloud_uf_filename])
  #   destination = "/tmp/${var.splunk_cloud_uf_filename}"
  # }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit", # added this to try and deal with issues with the deployment server reload and splunk restart steps
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",
      
    ## Create Splunk Ent Vars
      "ENVIRONMENT=${var.environment}",
      # "SPLUNK_PASSWORD=${random_string.splunk_password.result}",
      "SPLUNK_PASSWORD=${var.splunk_admin_pwd}",
      "LO_CONNECT_PASSWORD=${random_string.lo_connect_password.result}",
      "SPLUNK_ENT_VERSION=${var.splunk_ent_version}",
      "SPLUNK_FILENAME=${var.splunk_ent_filename}",
      "SPLUNK_ENTERPRISE_LICENSE_FILE=${var.splunk_enterprise_license_filename}",
      
    ## Write env vars to file (used for debugging)
      "echo $TOKEN > /tmp/access_token",
      "echo $REALM > /tmp/realm",
      "echo $ENVIRONMENT > /tmp/environment",
      "echo $SPLUNK_PASSWORD > /tmp/splunk_password",
      "echo $LO_CONNECT_PASSWORD > /tmp/lo_connect_password",
      "echo $SPLUNK_ENT_VERSION > /tmp/splunk_ent_version",
      "echo $SPLUNK_FILENAME > /tmp/splunk_filename",
      "echo $SPLUNK_ENTERPRISE_LICENSE_FILE > /tmp/splunk_enterprise_license_filename",
      # "echo $LBURL > /tmp/lburl",

    ## Install Splunk
      "sudo chmod +x /tmp/install_splunk_enterprise.sh",
      "sudo /tmp/install_splunk_enterprise.sh $SPLUNK_PASSWORD $SPLUNK_ENT_VERSION $SPLUNK_FILENAME $LO_CONNECT_PASSWORD",

    ## Add Apps
      "sudo tar -zxf /tmp/${var.splunk_enterprise_ta_linux_filename} --directory /opt/splunk/etc/deployment-apps",
      "sudo tar -zxf /tmp/${var.splunk_ta_otel_filename} --directory /opt/splunk/etc/deployment-apps",
      # "sudo tar -xvf /tmp/${var.splunk_cloud_uf_filename} -C /opt/splunk/etc/deployment-apps", # disabled to enable logs to be sent direct to deployment server indexer instead of the cloud instance
      "sudo tar -xvf /tmp/${var.config_explorer_filename} -C /opt/splunk/etc/apps",
      "sudo cp -r /opt/splunk/etc/deployment-apps/Splunk_TA_otel /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_windows",
      "sudo mv /opt/splunk/etc/deployment-apps/Splunk_TA_otel /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux",
      "sudo rm -fr /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_windows/linux_x86_64",
      "sudo rm -fr /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/windows_x86_64",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_logs_to_deployment_server",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_UF_logs_to_deployment_server/local", 

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/configs",

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/configs",

      "sudo cp /tmp/mysql-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/configs/mysql-otel-for-ta.yaml",
      "sudo cp /tmp/apache-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/configs/apache-otel-for-ta.yaml",
      "sudo cp /tmp/rocky-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/configs/rocky-otel-for-ta.yaml",
      "sudo cp /tmp/ms-sql-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/configs/ms-sql-otel-for-ta.yaml",

      "sudo cp /tmp/gateway_config.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/configs/gateway_config.yaml",
      "sudo cp /tmp/mysql-gw-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/configs/mysql-gw-otel-for-ta.yaml",
      "sudo cp /tmp/apache-gw-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/configs/apache-gw-otel-for-ta.yaml",

    ## Configure Apps
      "sudo chmod +x /tmp/configure_splunk_deployment_server.sh",
      "sudo /tmp/configure_splunk_deployment_server.sh $SPLUNK_PASSWORD $ENVIRONMENT $TOKEN $REALM",

    ## install NFR license
      "sudo mkdir /opt/splunk/etc/licenses/enterprise",
      "sudo cp /tmp/${var.splunk_enterprise_license_filename} /opt/splunk/etc/licenses/enterprise/${var.splunk_enterprise_license_filename}.lic",
      "sudo /opt/splunk/bin/splunk restart",

    ## Create Certs
      "sudo chmod +x /tmp/certs.sh",
      "sudo /tmp/certs.sh",
      "sudo cp /opt/splunk/etc/auth/sloccerts/mySplunkWebCert.pem /tmp/mySplunkWebCert.pem",
      "sudo chown ubuntu:ubuntu /tmp/mySplunkWebCert.pem",
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

output "splunk_password" {
  value = var.splunk_admin_pwd
}

output "lo_connect_password" {
  value = random_string.lo_connect_password.result
}

output "splunk_enterprise_private_ip" {
    value =  formatlist(
    "%s, %s",
    aws_instance.splunk_ent.*.tags.Name,
    aws_instance.splunk_ent.*.private_ip,
  )
}