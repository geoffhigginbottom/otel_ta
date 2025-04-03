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
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  tags = {
    Name = lower(join("-",[var.environment, "gateway", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "remote-exec" {
    inline = [
    ## Set Hostname and update
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

      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_universal_forwarder.sh /tmp/install_splunk_universal_forwarder.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.universalforwarder_filename} /tmp/${var.universalforwarder_filename}",

    ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}",
      "PASSWORD=${var.splunk_admin_pwd}",
      var.splunk_ent_count == "1" ? "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}" : "echo skipping",
      "PRIVATE_DNS=${self.private_dns}",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",
      "echo $PRIVATE_DNS > /tmp/PRIVATE_DNS",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder.sh",
      var.splunk_ent_count == "1" ? "/tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $PASSWORD $SPLUNK_IP $PRIVATE_DNS" : "echo skipping",
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

output "gateway_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.gateway.*.tags.Name,
    aws_instance.gateway.*.public_ip,
    aws_instance.gateway.*.private_dns,
  )
}