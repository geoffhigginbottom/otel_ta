resource "aws_instance" "ms_sql" {
  count                     = var.ms_sql_count
  ami                       = var.ms_sql_ami
  instance_type             = var.ms_sql_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  user_data = templatefile("${path.module}/scripts/ms_sql_userdata.ps1.tpl", {
    ms_sql_administrator_pwd            = var.ms_sql_administrator_pwd
    ms_sql_user                         = var.ms_sql_user
    ms_sql_user_pwd                     = var.ms_sql_user_pwd
    windows_universalforwarder_filename = var.windows_universalforwarder_filename
    windows_universalforwarder_url      = var.windows_universalforwarder_url
    splunk_admin_pwd                    = var.splunk_admin_pwd
    splunk_ent_private_ip               = aws_instance.splunk_ent[0].private_ip
    hostname                            = lower(join("-", ["ms-sql", count.index + 1]))
  })

  tags = {
    Name = lower(join("-",[var.environment, "ms-sql", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

output "ms_sql_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.ms_sql.*.tags.Name,
    aws_instance.ms_sql.*.public_ip,
    aws_instance.ms_sql.*.public_dns,
    
  )
}
