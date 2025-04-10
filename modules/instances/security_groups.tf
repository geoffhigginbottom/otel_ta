resource "aws_security_group" "instances_sg" {
  name          = "${var.environment}_Instances SG"
  description   = "Allow ingress traffic between Instances and Egress to Internet"
  vpc_id        = var.vpc_id

  ## Allow all traffic between group members
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  ## Allow SSH - required for Terraform
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow RDP - Enable Windows Remote Desktop
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow WinRM - Enable Windows Remote Desktop
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "splunk_ent_sg" {
  name          = "${var.environment}_Splunk Ent SG"
  description   = "Allow access to Splunk Enterprise"
  vpc_id        = var.vpc_id

  ## Allow all traffic between group members
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  ## Allow SSH - required for Terraform
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow access to UI
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    security_groups = [
      aws_security_group.instances_sg.id,
      aws_security_group.proxied_instances_sg.id
    ]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = [
      "108.128.26.145/32",
      "34.250.243.212/32",
      "54.171.237.247/32"
    ]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    security_groups = [
      aws_security_group.instances_sg.id,
      aws_security_group.proxied_instances_sg.id
    ]
  }

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    security_groups = [
      aws_security_group.instances_sg.id,
      aws_security_group.proxied_instances_sg.id
    ]
  }

  ## Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "proxy_server" {
  name          = "${var.environment}_proxy"
  description   = "Proxy Server"
  vpc_id        = var.vpc_id

 ## Allow SSH - required for Terraform
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow Proxy Traffic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [
      var.vpc_cidr_block
    ]
  }

  ## Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}

resource "aws_security_group" "proxied_instances_sg" {
  name          = "${var.environment} Proxied Instances SG"
  description   = "Allow ingress traffic between Proxy Instances and Egress to Proxy SG"
  vpc_id        = var.vpc_id

  ## Allow all traffic between group members
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  ## Allow SSH - required for Terraform
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow RDP - Enable Windows Remote Desktop
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow WinRM - Enable Windows Remote Desktop
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow all egress traffic
  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.proxy_server.id}"
    ]
  }

  egress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["${var.splunk_private_ip}/32"]
  }

  egress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["${var.splunk_private_ip}/32"]
  }

  egress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = ["${var.splunk_private_ip}/32"]
  }
}
