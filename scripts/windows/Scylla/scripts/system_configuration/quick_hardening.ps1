Write-Host "General Windows Hardening will now commence..."
Write-Warning "`nThis will make several modifications to your HKLM registry hive and default Windows settings`nIt is strongly recommended you review these before proceeding, and comment out those unnecessary or potentially harmful.`n"
Write-Host "A backup of your HKLM will be stored in $env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups.`n"
Read-Host "(ENTER to start or CTRL+C to cancel)"

Write-Log "General Windows hardening begins!"

Write-Log "Attempting to establish a registry backup..."
mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups | Out-Null
$curTime = Get-Date -Format "yyyyMMdd_HHmmss"
$regFile = "$env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups\backup_$curTime.reg"
$continueHardening = $false

reg export HKLM $regFile /y | Out-Null

if($LASTEXITCODE -eq "0")
{
    Write-Host "HKLM registry sucessfully backed up at $regFile"
    Write-Log "HKLM registry successfully backed up at $regFile"
    $continueHardening = $true
}
else
{
    Write-Warning "HKLM backup failed!"
    $confirmHardening = Read-Host "Continue without a backup? (Not recommended) (y/N):"
    if($confirmHardening -ilike "y*")
    {
        $continueHardening = $true
    }
}

if(!$continueHardening)
{
    Break
}

#### MAKE CHANGES BELOW IF NECESSARY ####
#### MAKE CHANGES BELOW IF NECESSARY ####
#### MAKE CHANGES BELOW IF NECESSARY ####

# Disable RDP
Write-Log "Disabling RDP..." 
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f

# Disable DNS Multicast
Write-Log "Disabling DNS Multicast..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f

# Disable parallel A and AAAA DNS queries
Write-Log "Disabling parallel A and AAAA DNS queries..."
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v DisableParallelAandAAAA /t REG_DWORD /d 1 /f

# Disable SMBv1
Write-Log "Disabling SMBv1..."
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 0 /f

# Enables UAC and Virtualization
Write-Log "Enabling UAC and Virtualization..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableVirtualization /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f

# Enable Safe DLL search mode and protection mode to prevent hijacking
Write-Log "Enabling Safe DLL search mode and protection mode..."
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v SafeDLLSearchMode /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v ProtectionMode /t REG_DWORD /d 1 /f

# Record command line data in process creation events eventid 4688
Write-Log "Enabling auditing of command line data in process creations events (ID 4688)..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

# Prevents the application of category-level audit policy from Group Policy and from the Local Security Policy administrative tool
Write-Log "Preventing the application of category-level audit policy from Group Policy and from the Local Security Policy administrative tool"
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v SCENoApplyLegacyAuditPolicy /t REG_DWORD /d 1 /f

# Enable PowerShell Logging
Write-Log "Enabling Powershell logging..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" /v EnableModuleLogging /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f

# Harden Lsass
Write-Log "Hardening LSASS..."
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" /v AuditLevel /t REG_DWORD /d 00000008 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 00000001 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" /v AllowProtectedCreds /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowDigest /t REG_DWORD /d 0 /f

# Encrypt/Sign outgoing secure channel traffic when possible
Write-Log "Signing outgoing secure channel traffic when possible..."
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" /v SealSecureChannel /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" /v SignSecureChannel /t REG_DWORD /d 1 /f

# Enable Windows Event Detailed Login
Write-Log "Enabling Windows Event Detailed Logins..."
AuditPol /set /subcategory:"Security Group Management" /success:enable /failure:enable
AuditPol /set /subcategory:"Process Creation" /success:enable /failure:enable
AuditPol /set /subcategory:"Logoff" /success:enable /failure:disable
AuditPol /set /subcategory:"Logon" /success:enable /failure:enable 
AuditPol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:disable
AuditPol /set /subcategory:"Removable Storage" /success:enable /failure:enable
AuditPol /set /subcategory:"SAM" /success:disable /failure:disable
AuditPol /set /subcategory:"Filtering Platform Policy Change" /success:disable /failure:disable
AuditPol /set /subcategory:"IPsec Driver" /success:enable /failure:enable
AuditPol /set /subcategory:"Security State Change" /success:enable /failure:enable
AuditPol /set /subcategory:"Security System Extension" /success:enable /failure:enable
AuditPol /set /subcategory:"System Integrity" /success:enable /failure:enable

# Enlarging Windows Event Security Log Size
Write-Log "Increaing the size of Windows Event Security Log..."
wevtutil sl Security /ms:1024000
wevtutil sl Application /ms:1024000
wevtutil sl System /ms:1024000
wevtutil sl "Windows Powershell" /ms:1024000
wevtutil sl "Microsoft-Windows-PowerShell/Operational" /ms:1024000

# Stop Remote Registry
Write-Log "Attempting to stop remote registry..."
net stop RemoteRegistry

# Flush dns
Write-Log "Flushing DNS..."
ipconfig /flushdns

# Stop WinRM
Write-Log "Attempting to stop Remote Management..."
net stop WinRM

# Disable Guest user
Write-Log "Disabling the Guest user account..."
net user Guest /active:NO 2>$null

Write-Log "Windows Hardening ends!"