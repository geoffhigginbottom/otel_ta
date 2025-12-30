resource "aws_instance" "apache_web_gw" {
  count                     = var.apache_web_gw_count
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "apache-gw", count.index + 1, "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }

  ebs_block_device {
    device_name = "/dev/xvdg"
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "apache-gw", count.index + 1, "data"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }

  tags = {
    Name = lower(join("-",[var.environment, "apache-gw", count.index + 1]))
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
      
      "sudo mkdir /media/data",
      "sudo echo 'type=83' | sudo sfdisk /dev/xvdg",
      "sudo mkfs.ext4 /dev/xvdg1",
      "sudo mount /dev/xvdg1 /media/data",

    ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
    
    ## Sync Non Public Files from S3
      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx.sh /tmp/xxx.sh",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx.yaml /tmp/xxx.yaml",
      # "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${} /tmp/${}",

      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_apache_web_server.sh /tmp/install_apache_web_server.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_universal_forwarder.sh /tmp/install_splunk_universal_forwarder.sh",

      "aws s3 cp s3://${var.s3_bucket_name}/config_files/locust.service /tmp/locust.service",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/locustfile.py /tmp/locustfile.py",

      # "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.universalforwarder_filename} /tmp/${var.universalforwarder_filename}",

    ## Install Apache
      "sudo chmod +x /tmp/install_apache_web_server.sh",
      "sudo /tmp/install_apache_web_server.sh",

    # Setup LoadGen Tools
      "sudo apt-get -y install python3-pip",

    ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}",
      "UNIVERSAL_FORWARDER_VERSION=${var.universalforwarder_version}",
      "PASSWORD=${var.splunk_admin_pwd}",
      "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}",
      "PRIVATE_DNS=${self.private_dns}",
      "HOSTNAME=${self.tags.Name}.local",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",
      "echo $PRIVATE_DNS > /tmp/PRIVATE_DNS",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder.sh",
      "/tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_VERSION $PASSWORD $SPLUNK_IP $PRIVATE_DNS",

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

output "apache_web_gw_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.apache_web_gw.*.tags.Name,
    aws_instance.apache_web_gw.*.public_ip,
    aws_instance.apache_web_gw.*.private_dns,
  )
}