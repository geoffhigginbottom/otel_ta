## Enable/Disable Modules - Values are set in quantity.auto.tfvars ###

variable "instances_enabled" {
  default = []
}

### AWS Variables ###
variable "profile" {
  default = []
}
variable "aws_access_key_id" {
  default = []
}
variable "aws_secret_access_key" {
  default = []
}
variable "vpc_id" {
  default = []
}
variable "vpc_name" {
  default = []
}
variable "vpc_cidr_block" {
  default = []
}
variable "public_subnet_ids" {
  default = {}
}
variable "private_subnet_ids" {
  default = {}
}
variable "subnet_count" {
  default = {}
}
variable "key_name" {
  default = []
}
variable "private_key_path" {
  default = []
}
variable "instance_type" {
  default = []
}
variable "gateway_instance_type" {
  default = []
}
variable "mysql_instance_type" {
  default = []
}
variable "ms_sql_instance_type" {
  default = []
}
variable "windows_server_instance_type" {
  default = []
}
variable "my_public_ip" {
  default = []
}
variable "eip" {
  default = []
}

variable "region" {
  description = "Select region (1:eu-west-1, 2:eu-west-3, 3:eu-central-1, 4:us-east-1, 5:us-east-2, 6:us-west-1, 7:us-west-2, 8:ap-southeast-1, 9:ap-southeast-2, 10:sa-east-1 )"
}

variable "aws_region" {
  description = "Provide the desired region"
  default = {
    "1"  = "eu-west-1"
    "2"  = "eu-west-3"
    "3"  = "eu-central-1"
    "4"  = "us-east-1"
    "5"  = "us-east-2"
    "6"  = "us-west-1"
    "7"  = "us-west-2"
    "8"  = "ap-southeast-1"
    "9"  = "ap-southeast-2"
    "10" = "sa-east-1"
  }
}

## Ubuntu AMI ##
data "aws_ami" "latest-ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # This is the owner id of Canonical who owns the official aws ubuntu images

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

## MS SQL Server AMI ##
data "aws_ami" "ms-sql-server" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-SQL_2022_Standard-*"]
    
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

## Windows Server AMI ##
data "aws_ami" "windows-server" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

### Instance Count Variables ###
variable "mysql_count" {
  default = {}
}
variable "apache_web_count" {
  default = {}
}
variable "ms_sql_count" {
  default = {}
}
variable "windows_server_count" {
  default = {}
}
variable "splunk_ent_count" {
  default = {}
}

variable "gateway_count" {
  default = {}
}
variable "gw_private_ip" {
  default = []
}
variable "mysql_gw_count" {
  default = {}
}
variable "apache_web_gw_count" {
  default = {}
}

### MySql Variables ###
variable "mysql_user" {
  default = []
}
variable "mysql_user_pwd" {
  default = []
}

### MS Sql Variables ###
variable "ms_sql_user" {
  default = []
}
variable "ms_sql_user_pwd" {
  default = []
}
variable "ms_sql_administrator_pwd" {
  default = []
}
variable "windows_server_administrator_pwd" {
  default = []
}

### SignalFX Variables ###
variable "access_token" {
  default = []
}
variable "api_url" {
  default = []
}
variable "realm" {
  default = []
}
variable "environment" {
  default = {}
}
# variable "windows_msi_url" {
#   default = {}
# }

### Splunk Enterprise Variables ###
variable "splunk_admin_pwd" {
  default = []
}
variable "splunk_private_ip" {
  default = []
}
variable "splunk_ent_filename" {
  default = {}
}
variable "splunk_ent_version" {
  default = {}
}
variable "splunk_ent_inst_type" {
  default = {}
}
variable "universalforwarder_filename" {
  default = {}
}
variable "universalforwarder_url" {
  default = {}
}
variable "windows_universalforwarder_filename" {
  default = {}
}
variable "windows_universalforwarder_url" {
  default = {}
}
variable "splunk_enterprise_files_local_path" {
  default = {}
}
variable "splunk_enterprise_license_filename" {
  default = {}
}
variable "splunk_enterprise_ta_linux_filename" {
  default = {}
}
variable "splunk_ta_otel_filename" {
  default = {}
}
variable "smart_agent_bundle_filename" {
  default = {}
}
variable "config_explorer_filename" {
  default = {}
}
variable "splunk_cloud_uf_filename" {
  default = {}
}

# variable "splunk_password" {
#   default = {}
# }

