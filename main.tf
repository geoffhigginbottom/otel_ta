# AWS Auth Configuration
provider "aws" {
  region     = lookup(var.aws_region, var.region)
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  default_tags {
    tags = {
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }
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

module "s3" {
  source                    = "./modules/s3"
  s3_bucket_name            = var.s3_bucket_name
  environment               = var.environment
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
  insecure_sg_rules                     = var.insecure_sg_rules
  ec2_instance_profile_name             = module.s3.ec2_instance_profile_name
  s3_bucket_name                        = var.s3_bucket_name
  instance_type                         = var.instance_type
  rocky_instance_type                   = var.rocky_instance_type
  mysql_instance_type                   = var.mysql_instance_type
  gateway_instance_type                 = var.gateway_instance_type
  ami                                   = data.aws_ami.ubuntu.id
  rocky_ami                             = data.aws_ami.rocky.id
  rocky_count                           = var.rocky_count
  gateway_count                         = var.gateway_count
  gw_private_ip                         = var.gw_private_ip
  proxy_server_private_ip               = var.proxy_server_private_ip
  mysql_count                           = var.mysql_count
  mysql_gw_count                        = var.mysql_gw_count
  mysql_user                            = var.ms_sql_user
  mysql_user_pwd                        = var.ms_sql_user_pwd
  ms_sql_count                          = var.ms_sql_count
  ms_sql_gw_count                       = var.ms_sql_gw_count
  auto_discovery_mysql_count            = var.auto_discovery_mysql_count
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
  apache_web_gw_count                   = var.apache_web_gw_count

  proxy_server_count                    = var.proxy_server_count
  proxied_apache_web_count              = var.proxied_apache_web_count

  splunk_admin_pwd                      = var.splunk_admin_pwd
  splunk_private_ip                     = var.splunk_private_ip
  splunk_ent_count                      = var.splunk_ent_count
  splunk_ent_version                    = var.splunk_ent_version
  splunk_ent_filename                   = var.splunk_ent_filename
  splunk_enterprise_license_filename    = var.splunk_enterprise_license_filename
  splunk_enterprise_ta_linux_filename   = var.splunk_enterprise_ta_linux_filename
  splunk_ta_otel_filename               = var.splunk_ta_otel_filename
  smart_agent_bundle_filename           = var.smart_agent_bundle_filename
  splunk_ent_inst_type                  = var.splunk_ent_inst_type
  splunk_cloud_uf_filename              = var.splunk_cloud_uf_filename
  config_explorer_filename              = var.config_explorer_filename
  universalforwarder_version            = var.universalforwarder_version
  universalforwarder_filename           = var.universalforwarder_filename
  universalforwarder_filename_rpm       = var.universalforwarder_filename_rpm
  windows_universalforwarder_filename   = var.windows_universalforwarder_filename
  windows_universalforwarder_url        = var.windows_universalforwarder_url
  my_public_ip                          = "${chomp(data.http.my_public_ip.response_body)}"
  eip                                   = var.eip
  certpath                              = var.certpath
  passphrase                            = var.passphrase
  fqdn                                  = var.fqdn
  country                               = var.country
  state                                 = var.state
  location                              = var.location
  org                                   = var.org
}


### Instances Outputs ###
output "OTEL_Gateway_Server" {
  value = var.instances_enabled ? module.instances.*.gateway_details : null
}
output "MySQL_Servers" {
  value = var.instances_enabled ? module.instances.*.mysql_details : null
}
# output "Auto_Discovery_MySQL_Servers" {
#   value = var.instances_enabled ? module.instances.*.auto_discovery_mysql_details : null
# }
output "MySQL_GW_Servers" {
  value = var.instances_enabled ? module.instances.*.mysql_gw_details : null
}
output "MS_SQL_Servers" {
  value = var.instances_enabled ? module.instances.*.ms_sql_details : null
}
output "MS_SQL_GW_Servers" {
  value = var.instances_enabled ? module.instances.*.ms_sql_gw_details : null
}
output "Apache_Web_Servers" {
  value = var.instances_enabled ? module.instances.*.apache_web_details : null
}
output "Apache_Web_GW_Servers" {
  value = var.instances_enabled ? module.instances.*.apache_web_gw_details : null
}
output "Proxied_Apache_Web_Servers" {
  value = var.instances_enabled ? module.instances.*.proxied_apache_web_details : null
}
output "Rocky_Servers" {
  value = var.instances_enabled ? module.instances.*.rocky_details : null
}

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
  value = var.instances_enabled ? module.instances.*.splunk_ent_url : null
}
output "splunk_url_fqdn" {
  value = var.instances_enabled ? module.instances.*.splunk_ent_url_fqdn : null
}