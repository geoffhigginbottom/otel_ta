<powershell>

Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${ms_sql_administrator_pwd}" -Force)

$LogFile = 'C:\sql-init.log'
function Write-SqlInitLog {
    param([string]$Message)
    Add-Content -Path $LogFile -Value ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') {0}" -f $Message)
}

function Wait-SqlServerReady {
    param([int]$MaxAttempts = 60)
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $svc = Get-Service -Name MSSQLSERVER -ErrorAction Stop
            if ($svc.Status -eq 'Running') {
                Invoke-Sqlcmd -ServerInstance localhost -Query 'SELECT 1' -ErrorAction Stop | Out-Null
                return
            }
        } catch {}
        Write-SqlInitLog "Waiting for SQL Server (attempt $i/$MaxAttempts)..."
        Start-Sleep -Seconds 10
    }
    throw "SQL Server did not become ready within $($MaxAttempts * 10) seconds"
}

try {
    Write-SqlInitLog 'Starting SQL Server configuration'
    Wait-SqlServerReady

    Write-SqlInitLog 'Enabling mixed mode authentication via xp_instance_regwrite'
    Invoke-Sqlcmd -ServerInstance localhost -Query @'
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode',
    REG_DWORD,
    2;
'@

    Restart-Service -Name MSSQLSERVER -Force
    Start-Sleep -Seconds 15
    Wait-SqlServerReady -MaxAttempts 30

    $authMode = Invoke-Sqlcmd -ServerInstance localhost -Query "SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS WindowsAuthOnly;"
    Write-SqlInitLog ("Authentication mode check - IsIntegratedSecurityOnly: {0} (0=mixed, 1=Windows only)" -f $authMode.WindowsAuthOnly)
    if ($authMode.WindowsAuthOnly -eq 1) {
        throw 'Mixed mode authentication is still disabled after registry update and service restart'
    }

    Write-SqlInitLog 'Creating login and granting permissions'
    Invoke-Sqlcmd -ServerInstance localhost -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'${ms_sql_user}')
    CREATE LOGIN [${ms_sql_user}] WITH PASSWORD = N'${ms_sql_user_pwd}', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [${ms_sql_user}] WITH PASSWORD = N'${ms_sql_user_pwd}', CHECK_POLICY = OFF;
"@
    Invoke-Sqlcmd -ServerInstance localhost -Query "GRANT VIEW SERVER STATE TO [${ms_sql_user}];"
    Invoke-Sqlcmd -ServerInstance localhost -Query "GRANT VIEW SERVER PERFORMANCE STATE TO [${ms_sql_user}];"
    Invoke-Sqlcmd -ServerInstance localhost -Query "GRANT VIEW ANY DEFINITION TO [${ms_sql_user}];"
    Invoke-Sqlcmd -ServerInstance localhost -Query "GRANT VIEW ANY DATABASE TO [${ms_sql_user}];"

    Invoke-Sqlcmd -ServerInstance localhost -Username ${ms_sql_user} -Password '${ms_sql_user_pwd}' -Query 'SELECT 1' -ErrorAction Stop | Out-Null
    Write-SqlInitLog 'SQL login verification succeeded'
} catch {
    Write-SqlInitLog ("ERROR: {0}" -f $_)
    throw
}

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

$hostname = "${hostname}"
# Write the hostname to a file for verification
Set-Content -Path "C:\Hostname.txt" -Value $hostname

$domain = $PrivateIpDnsName -replace "^[^.]+\.", ""

$fqdn = "$hostname.$domain"
# Write the fqdn to a file for verification
Set-Content -Path "C:\fqdn.txt" -Value $fqdn

# Create the file with specific contents
$filePath = "$splunk_home\etc\system\local\inputs.conf"
$fileContent = @"
[WinEventLog://System]
_meta = host.name::$fqdn

[WinEventLog://Security]
_meta = host.name::$fqdn

[WinEventLog://Application]
_meta = host.name::$fqdn
"@
Set-Content -Path $filePath -Value $fileContent -Encoding UTF8

Rename-Computer -NewName $hostname -Force
Restart-Computer -Force

</powershell>
