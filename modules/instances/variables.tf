### AWS Variables ###
variable "region" {
  default = {}
}
variable "vpc_id" {
  default = []
}
variable "vpc_cidr_block" {
  default = []
}
variable "public_subnet_ids" {
  default = {}
}
variable "key_name" {
  default = []
}
variable "private_key_path"{
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
variable "ami" {
  default = {}
}
variable "ms_sql_ami" {
  default = {}
}
variable "windows_server_ami" {
  default = {}
}
variable "my_public_ip" {
  default = []
}
variable "eip" {
  default = []
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
variable "ballast" {
  default = []
}
variable "environment" {
  default = []
}

### Splunk Enterprise Variables ###
variable "splunk_admin_pwd" {
  default = []
}
variable "splunk_private_ip" {
  default = []
}
variable "splunk_ent_version" {
  default = {}
}
variable "splunk_ent_filename" {
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