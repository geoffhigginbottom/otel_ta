resource "aws_instance" "mysqlgw" {
  count                     = var.mysql_gw_count
  ami                       = var.ami
  instance_type             = var.mysql_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  tags = {
    Name = lower(join("_",[var.environment, "mysqlgw", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_mysql.sh"
    destination = "/tmp/install_mysql.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/mysqld.cnf"
    destination = "/tmp/mysqld.cnf"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder.sh"
    destination = "/tmp/install_splunk_universal_forwarder.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/mysql_loadgen.py"
    destination = "/tmp/mysql_loadgen.py"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/mysql_loadgen.service"
    destination = "/tmp/mysql_loadgen.service"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/mysql_loadgen_start.sh"
    destination = "/tmp/mysql_loadgen_start.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/mysql_loadgen_stop.sh"
    destination = "/tmp/mysql_loadgen_stop.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

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
      "UNIVERSAL_FORWARDER_URL=${var.universalforwarder_url}",
      # "PASSWORD=${random_string.apache_universalforwarder_password.result}",
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

output "mysql_gw_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.mysqlgw.*.tags.Name,
    aws_instance.mysqlgw.*.public_ip,
  )
}