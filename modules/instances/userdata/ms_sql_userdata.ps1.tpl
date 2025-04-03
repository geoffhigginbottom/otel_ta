<powershell>

Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${ms_sql_administrator_pwd}" -Force)

# Install AWS CLI (for accessing secure S3 Buckets)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /qn
# Start-Sleep -Seconds 30  # Wait for the AWS CLI to finish installing

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s = new-object('Microsoft.SqlServer.Management.Smo.Server') localhost
$nm = $s.Name
$mode = $s.Settings.LoginMode
$s.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode] 'Mixed'
$s.Alter()
Restart-Service -Name MSSQLSERVER -f

Invoke-Sqlcmd -Query "CREATE LOGIN [signalfxagent] WITH PASSWORD = '${ms_sql_user_pwd}';" -ServerInstance localhost
Invoke-Sqlcmd -Query "GRANT VIEW SERVER STATE TO [${ms_sql_user}];" -ServerInstance localhost
Invoke-Sqlcmd -Query "GRANT VIEW ANY DEFINITION TO [${ms_sql_user}];" -ServerInstance localhost

New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'SPLUNK_SQL_USER' -Value "${ms_sql_user}"
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'SPLUNK_SQL_USER_PWD' -Value "${ms_sql_user_pwd}"

Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

wget -O "${windows_universalforwarder_filename}" "${windows_universalforwarder_url}"
msiexec.exe /i "${windows_universalforwarder_filename}" AGREETOLICENSE=yes SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD="${splunk_admin_pwd}" /quiet

Start-Sleep 120

$splunk_home="C:\Program Files\SplunkUniversalForwarder"
& $splunk_home\bin\splunk set deploy-poll ${splunk_ent_private_ip}:8089 -auth SplunkAdmin:${splunk_admin_pwd}

# Fetch the instance's private IP DNS name
$privateIpDnsName = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/local-hostname").ToString()
# Write the DNS name to a file for verification
Set-Content -Path "C:\PrivateIpDnsName.txt" -Value $privateIpDnsName

$domain = $PrivateIpDnsName -replace "^[^.]+\.", ""

$hostname = "${hostname}"
# Write the hostname to a file for verification
Set-Content -Path "C:\Hostname.txt" -Value $hostname

$fqdn = "$hostname.$domain"
# Write the fqdn to a file for verification
Set-Content -Path "C:\fqdn.txt" -Value $fqdn

# Create the file with specific contents
$filePath = "$splunk_home\etc\system\local\inputs.conf"
$fileContent = @"
[WinEventLog://System]
_meta = host.name::$privateIpDnsName

[WinEventLog://Security]
_meta = host.name::$privateIpDnsName

[WinEventLog://Application]
_meta = host.name::$privateIpDnsName
"@
Set-Content -Path $filePath -Value $fileContent -Encoding UTF8

Rename-Computer -NewName $hostname -Force
Restart-Computer -Force

</powershell>
