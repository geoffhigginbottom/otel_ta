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
  iam_instance_profile      = var.ec2_instance_profile_name

  tags = {
    Name = lower(join("-",[var.environment, "splunk-ent", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "remote-exec" {
    inline = [
    ## Set Hostname and update
      "set -o errexit", # added this to try and deal with issues with the deployment server reload and splunk restart steps
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

    ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
    
    ## Sync Non Public Files from S3
      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx.sh /tmp/xxx.sh",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx.yaml /tmp/xxx.yaml",
      # "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${} /tmp/${}",

      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_enterprise.sh /tmp/install_splunk_enterprise.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/configure_splunk_deployment_server.sh /tmp/configure_splunk_deployment_server.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/certs.sh /tmp/certs.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_inputs_conf_spec.sh /tmp/update_inputs_conf_spec.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_mysql_inputs.sh /tmp/update_mysql_inputs.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_mysql_inputs_gw.sh /tmp/update_mysql_inputs_gw.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_splunk_ta_otel_sh.sh /tmp/update_splunk_ta_otel_sh.sh",

      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql-otel-for-ta.yaml /tmp/mysql-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql-gw-otel-for-ta.yaml /tmp/mysql-gw-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/apache-otel-for-ta.yaml /tmp/apache-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/rocky-otel-for-ta.yaml /tmp/rocky-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/apache-gw-otel-for-ta.yaml /tmp/apache-gw-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/ms-sql-otel-for-ta.yaml /tmp/ms-sql-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/ms-sql-gw-otel-for-ta.yaml /tmp/ms-sql-gw-otel-for-ta.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/gateway_config.yaml /tmp/gateway_config.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/inputs.conf.spec /tmp/inputs.conf.spec",

      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_ent_filename} /tmp/${var.splunk_ent_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_enterprise_license_filename} /tmp/${var.splunk_enterprise_license_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_enterprise_ta_linux_filename} /tmp/${var.splunk_enterprise_ta_linux_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_ta_otel_filename} /tmp/${var.splunk_ta_otel_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.config_explorer_filename} /tmp/${var.config_explorer_filename}",

    ## Create Splunk Ent Vars
      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",
      "ENVIRONMENT=${var.environment}",
      # "SPLUNK_PASSWORD=${random_string.splunk_password.result}",
      "SPLUNK_PASSWORD=${var.splunk_admin_pwd}",
      "LO_CONNECT_PASSWORD=${random_string.lo_connect_password.result}",
      "SPLUNK_ENT_VERSION=${var.splunk_ent_version}",
      "SPLUNK_FILENAME=${var.splunk_ent_filename}",
      "SPLUNK_ENTERPRISE_LICENSE_FILE=${var.splunk_enterprise_license_filename}",
      "MYSQL_USER=${var.mysql_user}",
      "MYSQL_USER_PWD=${var.mysql_user_pwd}",
      
    ## Write env vars to file (used for debugging)
      "echo $TOKEN > /tmp/access_token",
      "echo $REALM > /tmp/realm",
      "echo $ENVIRONMENT > /tmp/environment",
      "echo $SPLUNK_PASSWORD > /tmp/splunk_password",
      "echo $LO_CONNECT_PASSWORD > /tmp/lo_connect_password",
      "echo $SPLUNK_ENT_VERSION > /tmp/splunk_ent_version",
      "echo $SPLUNK_FILENAME > /tmp/splunk_filename",
      "echo $SPLUNK_ENTERPRISE_LICENSE_FILE > /tmp/splunk_enterprise_license_filename",
      "echo $MYSQL_USER > /tmp/mysql_user",
      "echo $MYSQL_USER_PWD > /tmp/mysql_user_pwd",

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

      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/local",
      "sudo mkdir /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/configs",

      "sudo cp /tmp/mysql-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql/configs/mysql-otel-for-ta.yaml",
      "sudo cp /tmp/apache-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache/configs/apache-otel-for-ta.yaml",
      "sudo cp /tmp/rocky-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_rocky/configs/rocky-otel-for-ta.yaml",
      "sudo cp /tmp/ms-sql-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql/configs/ms-sql-otel-for-ta.yaml",

      "sudo cp /tmp/gateway_config.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_gateway/configs/gateway_config.yaml",
      "sudo cp /tmp/mysql-gw-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_mysql_gw/configs/mysql-gw-otel-for-ta.yaml",
      "sudo cp /tmp/apache-gw-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_apache_gw/configs/apache-gw-otel-for-ta.yaml",
      "sudo cp /tmp/ms-sql-gw-otel-for-ta.yaml /opt/splunk/etc/deployment-apps/Splunk_TA_otel_apps_ms_sql_gw/configs/ms-sql-gw-otel-for-ta.yaml",

    ## Configure Apps
      "sudo chmod +x /tmp/configure_splunk_deployment_server.sh",
      "sudo /tmp/configure_splunk_deployment_server.sh $SPLUNK_PASSWORD $ENVIRONMENT $TOKEN $REALM",

    ##### TESTING Update Config for MySQL Parameters TESTING #####
      "sudo chmod +x /tmp/update_inputs_conf_spec.sh",
      "sudo chmod +x /tmp/update_mysql_inputs.sh",
      "sudo chmod +x /tmp/update_mysql_inputs_gw.sh",
      "sudo chmod +x /tmp/update_splunk_ta_otel_sh.sh",

      "sudo /tmp/update_inputs_conf_spec.sh",
      "sudo /tmp/update_mysql_inputs.sh $MYSQL_USER $MYSQL_USER_PWD",
      "sudo /tmp/update_mysql_inputs_gw.sh $MYSQL_USER $MYSQL_USER_PWD",
      "sudo /tmp/update_splunk_ta_otel_sh.sh",

      "sudo /opt/splunk/bin/splunk reload deploy-server -auth admin:${var.splunk_admin_pwd}", # Does this work??? latest edit

    # ####### PATCH FOR PROXY - TEMP UNTIL PROXY SUPORT ADDED #######
    #   "sudo sed -i '/# Begin autogenerated code/i export http_proxy=\"http://${var.proxy_server_private_ip}:8080/\"' /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/linux_x86_64/bin/Splunk_TA_otel.sh",
    #   "sudo sed -i '/# Begin autogenerated code/i export https_proxy=\"http://${var.proxy_server_private_ip}:8080/\"' /opt/splunk/etc/deployment-apps/Splunk_TA_otel_base_linux/linux_x86_64/bin/Splunk_TA_otel.sh",
    # ####### PATCH FOR PROXY - TEMP UNTIL PROXY SUPORT ADDED #######

    ## install NFR license
      "sudo mkdir /opt/splunk/etc/licenses/enterprise",
      "sudo cp /tmp/${var.splunk_enterprise_license_filename} /opt/splunk/etc/licenses/enterprise/${var.splunk_enterprise_license_filename}.lic",
      "sudo /opt/splunk/bin/splunk restart",

    ## Create Certs
     # Create FQDN Ent Vars
      "CERTPATH=${var.certpath}",
      "PASSPHRASE=${var.passphrase}",
      "FQDN=${var.fqdn}",
      "COUNTRY=${var.country}",
      "STATE=${var.state}",
      "LOCATION=${var.location}",
      "ORG=${var.org}",
     # Run Script
      "sudo chmod +x /tmp/certs.sh",
      "sudo /tmp/certs.sh $CERTPATH $PASSPHRASE $FQDN $COUNTRY $STATE $LOCATION $ORG",
    # Create copy in /tmp for easy access for setting up Log Observer Conect
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