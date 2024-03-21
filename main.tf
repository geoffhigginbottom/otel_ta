# AWS Auth Configuration
provider "aws" {
  region     = lookup(var.aws_region, var.region)
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "signalfx" {
  auth_token = var.access_token
  api_url    = var.api_url
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "vpc" {
  source                = "./modules/vpc"
  vpc_name              = var.environment
  vpc_cidr_block        = var.vpc_cidr_block
  subnet_count          = var.subnet_count
  region                = lookup(var.aws_region, var.region)
  environment           = var.environment
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}

module "instances" {
  source                                = "./modules/instances"
  count                                 = var.instances_enabled ? 1 : 0
  access_token                          = var.access_token
  api_url                               = var.api_url
  realm                                 = var.realm
  environment                           = var.environment
  region                                = lookup(var.aws_region, var.region)
  vpc_id                                = module.vpc.vpc_id
  vpc_cidr_block                        = var.vpc_cidr_block
  public_subnet_ids                     = module.vpc.public_subnet_ids
  key_name                              = var.key_name
  private_key_path                      = var.private_key_path
  instance_type                         = var.instance_type
  mysql_instance_type                   = var.mysql_instance_type
  gateway_instance_type                 = var.gateway_instance_type
  ami                                   = data.aws_ami.latest-ubuntu.id
  gateway_count                         = var.gateway_count
  mysql_count                           = var.mysql_count
  mysql_count_gw                        = var.mysql_count_gw
  mysql_user                            = var.ms_sql_user
  mysql_user_pwd                        = var.ms_sql_user_pwd
  ms_sql_count                          = var.ms_sql_count
  ms_sql_user                           = var.ms_sql_user
  ms_sql_user_pwd                       = var.ms_sql_user_pwd
  ms_sql_administrator_pwd              = var.ms_sql_administrator_pwd
  ms_sql_instance_type                  = var.ms_sql_instance_type
  ms_sql_ami                            = data.aws_ami.ms-sql-server.id
  windows_server_count                  = var.windows_server_count
  windows_server_administrator_pwd      = var.windows_server_administrator_pwd
  windows_server_instance_type          = var.windows_server_instance_type
  windows_server_ami                    = data.aws_ami.windows-server.id
  apache_web_count                      = var.apache_web_count
  splunk_admin_pwd                      = var.splunk_admin_pwd
  splunk_private_ip                     = var.splunk_private_ip
  splunk_ent_count                      = var.splunk_ent_count
  splunk_ent_version                    = var.splunk_ent_version
  splunk_ent_filename                   = var.splunk_ent_filename
  splunk_enterprise_files_local_path    = var.splunk_enterprise_files_local_path
  splunk_enterprise_license_filename    = var.splunk_enterprise_license_filename
  splunk_enterprise_ta_linux_filename   = var.splunk_enterprise_ta_linux_filename
  splunk_ta_otel_filename               = var.splunk_ta_otel_filename
  smart_agent_bundle_filename           = var.smart_agent_bundle_filename
  splunk_ent_inst_type                  = var.splunk_ent_inst_type
  splunk_cloud_uf_filename              = var.splunk_cloud_uf_filename
  config_explorer_filename              = var.config_explorer_filename
  universalforwarder_filename           = var.universalforwarder_filename
  universalforwarder_url                = var.universalforwarder_url
  windows_universalforwarder_filename   = var.windows_universalforwarder_filename
  windows_universalforwarder_url        = var.windows_universalforwarder_url
  my_public_ip                          = var.my_public_ip
}


### Instances Outputs ###
# output "OTEL_Gateway_Servers" {
#   value = var.instances_enabled ? module.instances.*.gateway_details : null
# }
output "MySQL_Servers" {
  value = var.instances_enabled ? module.instances.*.mysql_details : null
}
output "MS_SQL_Servers" {
  value = var.instances_enabled ? module.instances.*.ms_sql_details : null
}
output "Apache_Web_Servers" {
  value = var.instances_enabled ? module.instances.*.apache_web_details : null
}
# output "collector_lb_dns" {
#   value = var.instances_enabled ? module.instances.*.gateway_lb_int_dns : null
# }
# output "Windows_Servers" {
#   value = var.instances_enabled ? module.instances.*.windows_server_details : null
# }

### Splunk Enterprise Outputs ###
output "Splunk_Enterprise_Server" {
  value = var.instances_enabled ? module.instances.*.splunk_ent_details : null
}
output "splunk_password" {
  value = var.instances_enabled ? module.instances.*.splunk_password : null
  # sensitive = true
}
output "lo_connect_password" {
  value = var.instances_enabled ? module.instances.*.lo_connect_password : null
  # sensitive = true
}
output "splunk_enterprise_private_ip" {
  value = var.instances_enabled ? module.instances.*.splunk_enterprise_private_ip : null
  # sensitive = true
}
output "splunk_url" {
  value = var.instances_enabled ? module.instances.*.splunk_ent_urls : null
}
