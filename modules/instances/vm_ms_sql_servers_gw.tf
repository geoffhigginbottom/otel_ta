resource "aws_instance" "ms_sql_gw" {
  count                     = var.ms_sql_gw_count
  ami                       = var.ms_sql_ami
  instance_type             = var.ms_sql_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  user_data = <<EOF
  <powershell>

    Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${var.ms_sql_administrator_pwd}" -Force)

    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
    $s = new-object('Microsoft.SqlServer.Management.Smo.Server') localhost
    $nm = $s.Name
    $mode = $s.Settings.LoginMode
    $s.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode] 'Mixed'
    $s.Alter()
    Restart-Service -Name MSSQLSERVER -f

    Invoke-Sqlcmd -Query "CREATE LOGIN [signalfxagent] WITH PASSWORD = '${var.ms_sql_user_pwd}';" -ServerInstance localhost
    Invoke-Sqlcmd -Query "GRANT VIEW SERVER STATE TO [${var.ms_sql_user}];" -ServerInstance localhost
    Invoke-Sqlcmd -Query "GRANT VIEW ANY DEFINITION TO [${var.ms_sql_user}];" -ServerInstance localhost

    New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'SPLUNK_SQL_USER' -Value ${var.ms_sql_user}
    New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'SPLUNK_SQL_USER_PWD' -Value ${var.ms_sql_user_pwd}

    Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
    Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

    wget -O ${var.windows_universalforwarder_filename} "${var.windows_universalforwarder_url}"
    msiexec.exe /i ${var.windows_universalforwarder_filename} AGREETOLICENSE=yes SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=${var.splunk_admin_pwd} /quiet

    Start-Sleep 120

    $splunk_home="C:\Program Files\SplunkUniversalForwarder"
    & $splunk_home\bin\splunk set deploy-poll ${aws_instance.splunk_ent.0.private_ip}:8089 -auth SplunkAdmin:${var.splunk_admin_pwd}

    # Fetch the instance's private IP DNS name
    $privateIpDnsName = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/local-hostname").ToString()

    # Write the DNS name to a file for verification
    Set-Content -Path "C:\PrivateIpDnsName.txt" -Value $privateIpDnsName

    $hostname = ${lower(join("-",[var.environment, "ms-sql-gw", count.index + 1]))}

    # Write the hostname to a file for verification
    Set-Content -Path "C:\Hostname.txt" -Value $hostname

    # Create the file with specific contents
    $filePath = "$splunk_home\etc\system\local\inputs.conf"
    # Indentation seems to matter!
    $fileContent = @"
[WinEventLog://System]
_meta = host.name::$hostname

[WinEventLog://Security]
_meta = host.name::$hostname

[WinEventLog://Application]
_meta = host.name::$hostname
"@
    Set-Content -Path $filePath -Value $fileContent -Encoding UTF8

    & $splunk_home\bin\splunk restart
  </powershell>
  EOF

  tags = {
    Name = lower(join("-",[var.environment, "ms-sql-gw", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

output "ms_sql_gw_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.ms_sql_gw.*.tags.Name,
    aws_instance.ms_sql_gw.*.public_ip,
    aws_instance.ms_sql_gw.*.public_dns,
    
  )
}
