resource "aws_instance" "auto_discovery_mysql" {
  count                     = var.auto_discovery_mysql_count
  ami                       = var.ami
  instance_type             = var.mysql_instance_type
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
      Name                          = lower(join("-", [var.environment, "auto-discovery-mysql", count.index + 1, "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }

  tags = {
    Name = lower(join("-",[var.environment, "auto-discovery-mysql", count.index + 1]))
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

      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_mysql.sh /tmp/install_mysql.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_universal_forwarder.sh /tmp/install_splunk_universal_forwarder.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/mysql_loadgen.py /tmp/mysql_loadgen.py",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/mysql_loadgen_start.sh /tmp/mysql_loadgen_start.sh",

      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysqld.cnf /tmp/mysqld.cnf",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql_loadgen.service /tmp/mysql_loadgen.service",

      # "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.universalforwarder_filename} /tmp/${var.universalforwarder_filename}",

    ## Install MySQL
      "sudo chmod +x /tmp/install_mysql.sh",
      "sudo /tmp/install_mysql.sh",
      "sudo mysql -u root -p'root' -e \"CREATE USER '${var.mysql_user}'@'localhost' IDENTIFIED BY '${var.mysql_user_pwd}';\"",
      "sudo mysql -u root -p'root' -e \"GRANT USAGE ON *.* TO '${var.mysql_user}'@'localhost';\"",
      "sudo mysql -u root -p'root' -e \"GRANT SELECT ON *.* TO '${var.mysql_user}'@'localhost';\"",
      "sudo mysql -u root -p'root' -e \"GRANT REPLICATION CLIENT ON *.* TO '${var.mysql_user}'@'localhost';\"",
    
    ## Setup LoadGen Tools
      "sudo apt-get -y install python3-pip",
      "sudo pip install mysql-connector",
      "sudo pip install mysql-connector-python[cext]",
      "mysql -u root -p'root' -e \"CREATE DATABASE loadgen;\"", # mysql -u root -p'root' -e "CREATE DATABASE loadgen;"
      "mysql -u root -p'root' -e \"USE loadgen; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) NOT NULL, email VARCHAR(100) NOT NULL);\"", # mysql -u root -p'root' -e "USE loadgen; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) NOT NULL, email VARCHAR(100) NOT NULL);"
      "mysql -u root -p'root' -e \"USE loadgen; INSERT INTO users (username, email) VALUES ('user1', 'user1@example.com'), ('user2', 'user2@example.com');\"", # mysql -u root -p'root' -e "USE loadgen; INSERT INTO users (username, email) VALUES ('user1', 'user1@example.com'), ('user2', 'user2@example.com');"
      "mysql -u root -p'root' -e \"USE loadgen; GRANT INSERT, SELECT, CREATE, UPDATE, DELETE ON users TO '${var.mysql_user}'@'localhost';\"", # mysql -u root -p'root' -e "USE loadgen; GRANT INSERT, SELECT, CREATE, UPDATE, DELETE ON users TO 'signalfxagent'@'localhost';"
      "sudo mv /tmp/mysql_loadgen.py /home/ubuntu/mysql_loadgen.py",
      "sudo chmod +x /home/ubuntu/mysql_loadgen.py",
      "sudo mv /tmp/mysql_loadgen_start.sh /home/ubuntu/mysql_loadgen_start.sh",
      "sudo mv /tmp/mysql_loadgen_stop.sh /home/ubuntu/mysql_loadgen_stop.sh",
      "sudo chmod +x /home/ubuntu/mysql_loadgen_start.sh",
      "sudo chmod +x /home/ubuntu/mysql_loadgen_stop.sh",
      "sudo mv /tmp/mysql_loadgen.service /etc/systemd/system/mysql_loadgen.service",
      "sudo chmod +x /etc/systemd/system/mysql_loadgen.service",

    ## Update MySql Logging 
      "sudo cp /tmp/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo systemctl restart mysql",

    ## Generate Vars
      "UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}",
      "UNIVERSAL_FORWARDER_VERSION=${var.universalforwarder_version}",
      "PASSWORD=${var.splunk_admin_pwd}",
      "SPLUNK_IP=${aws_instance.splunk_ent.0.private_ip}",
      "PRIVATE_DNS=${self.private_dns}",

    ## Write env vars to file (used for debugging)
      "echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME",
      "echo $PASSWORD > /tmp/PASSWORD",
      "echo $SPLUNK_IP > /tmp/SPLUNK_IP",
      "echo $PRIVATE_DNS > /tmp/PRIVATE_DNS",

    ## Install Splunk Universal Forwarder
      "sudo chmod +x /tmp/install_splunk_universal_forwarder.sh",
      "/tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_VERSION $PASSWORD $SPLUNK_IP $PRIVATE_DNS",

    ## Run MySQL Loadgen Script
      "sudo systemctl daemon-reload",
      "sudo systemctl restart mysql_loadgen",
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

output "auto_discovery_mysql_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.auto_discovery_mysql.*.tags.Name,
    aws_instance.auto_discovery_mysql.*.public_ip,
    aws_instance.auto_discovery_mysql.*.private_dns,
  )
}