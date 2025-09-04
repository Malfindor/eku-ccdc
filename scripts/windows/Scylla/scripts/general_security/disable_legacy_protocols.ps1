#Requires -Version 5.1 -RunAsAdministrator
<#
.SYNOPSIS
Requires PS 5.1 and Administrator rights.

.NOTES
Author: Logan Jackson
Date: 2024

.LINK
Website: https://lj-sec.github.io/
#>

if($MyInvocation.PSCommandPath -notlike "*scylla_core.ps1")
{
    Write-Error "Script not launched from core Scylla script."
    Exit 1
}

function Backup-RegKey
{
    param(
        [string]$KeyPath,
        [string]$BackupPath = "$env:HOMEDRIVE\Scylla\Registry_Backups\RegBackup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).reg"
    )
    try
    {
        reg export "$KeyPath" $BackupPath /y | Out-Null
        Write-Log -Message "Backed up $KeyPath to $BackupPath" -Echo
    }
    catch
    {
        Write-Log -Message "Could not backup key $($KeyPath): $_" -Echo
    }
}

function Set-RegValueSafe
{
    param(
        [string]$Path,
        [string]$Name,
        [Object]$Value,
        [string]$Type = 'DWORD'
    )
    try
    {
        if (-not (Test-Path $Path))
        {
            New-Item -Path $Path -Force | Out-Null
            Write-Log -Message "Created registry key: $Path" -Echo
        }
        # Check the current value if it exists
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ($null -ne $current -and $current -eq $Value)
        {
            Write-Log -Message "$Name already set to $Value at $Path" -Echo
        }
        else
        {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
            Write-Log -Message "Set $Name to $Value at $Path" -Echo
        }
    }
    catch
    {
        Write-Log -Message "Failed to set $Name in $($Path): $_" -Echo
    }
}

# --- Component Functions ---

function Disable-LLMNR
{
    Write-Log -Message "Disabling LLMNR..." -Echo
    $LLMNRPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    Backup-RegKey -KeyPath $LLMNRPath
    Set-RegValueSafe -Path $LLMNRPath -Name "EnableMulticast" -Value 0 -Type DWORD
}

function Disable-SMBv1
{
    Write-Log -Message "Disabling SMBv1..." -Echo
    $SMBKey = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    Backup-RegKey -KeyPath $SMBKey
    Set-RegValueSafe -Path $SMBKey -Name "SMB1" -Value 0 -Type DWORD
    try
    {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop
        Write-Log -Message "SMBv1 optional feature disabled." -Echo
    }
    catch
    {
        Write-Log -Message "Failed to disable SMBv1 optional feature: $_" -Echo
    }
}

function Update-TLS
{
    Write-Log -Message "Configuring TLS protocols..." -Echo
    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

    # TLS 1.0 (disable)
    foreach ($side in @("Server", "Client"))
    {
        $path = Join-Path $basePath "TLS 1.0\$side"
        Backup-RegKey -KeyPath $path
        Set-RegValueSafe -Path $path -Name "Enabled" -Value 0
        Set-RegValueSafe -Path $path -Name "DisabledByDefault" -Value 1
    }

    # TLS 1.1 (disable)
    foreach ($side in @("Server", "Client"))
    {
        $path = Join-Path $basePath "TLS 1.1\$side"
        Backup-RegKey -KeyPath $path
        Set-RegValueSafe -Path $path -Name "Enabled" -Value 0
        Set-RegValueSafe -Path $path -Name "DisabledByDefault" -Value 1
    }

    # TLS 1.2 (enable)
    foreach ($side in @("Server", "Client"))
    {
        $path = Join-Path $basePath "TLS 1.2\$side"
        Backup-RegKey -KeyPath $path
        Set-RegValueSafe -Path $path -Name "Enabled" -Value 1
        Set-RegValueSafe -Path $path -Name "DisabledByDefault" -Value 0
    }
}

function Disable-WeakAuth
{
    Write-Log -Message "Disabling weak authentication (LM/NTLMv1)..." -Echo
    $lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Backup-RegKey -KeyPath $lsaPath
    # Set LmCompatibilityLevel to 5 (Send NTLMv2 response only. Refuse LM & NTLM)
    Set-RegValueSafe -Path $lsaPath -Name "LmCompatibilityLevel" -Value 5
}

function Disable-WSDiscovery
{
    Write-Log -Message "Disabling WS-Discovery (SSDPSRV)..." -Echo
    try {
        Stop-Service -Name "SSDPSRV" -Force -ErrorAction Stop
        Set-Service -Name "SSDPSRV" -StartupType Disabled -ErrorAction Stop
        Write-Log -Message "WS-Discovery (SSDPSRV) disabled." -Echo
    }
    catch {
        Write-Log -Message "Could not disable SSDPSRV: $_" -Echo
    }
}

function Disable-RDPUDP
{
    Write-Log -Message "Disabling RDP UDP (forcing RDP over TCP)..." -Echo
    $rdpPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services'
    Backup-RegKey -KeyPath $rdpPath
    Set-RegValueSafe -Path $rdpPath -Name "fUseUdp" -Value 0
}

function Disable-SNMP
{
    Write-Log -Message "Disabling SNMP service..." -Echo
    try
    {
        Remove-WindowsFeature -Name SNMP-Service -ErrorAction Stop
        Write-Log -Message "SNMP service removed." -Echo
    }
    catch
    {
        Write-Log -Message "Could not remove SNMP service: $_" -Echo
    }
}

function Show-Menu
{
    Write-Log -Message "Select the services to configure:" -Echo
    Write-Log -Message "1. Disable LLMNR" -Echo
    Write-Log -Message "2. Disable SMBv1" -Echo
    Write-Log -Message "3. Configure TLS (Disable TLS 1.0 & 1.1; Enable TLS 1.2)" -Echo
    Write-Log -Message "4. Disable weak authentication (LM/NTLMv1)" -Echo
    Write-Log -Message "5. Disable WS-Discovery (SSDPSRV)" -Echo
    Write-Log -Message "6. Disable RDP UDP" -Echo
    Write-Log -Message "7. Disable SNMP" -Echo
    Write-Log -Message "8. Apply all of the above" -Echo
}

Show-Menu
$selection = Read-Host "Enter your choices (comma-separated, e.g., 1,3,5)"
$choices = $selection -split ',' | ForEach-Object { $_.Trim() }

foreach ($choice in $choices) {
    switch ($choice) {
        "1" { Disable-LLMNR }
        "2" { Disable-SMBv1 }
        "3" { Update-TLS }
        "4" { Disable-WeakAuth }
        "5" { Disable-WSDiscovery }
        "6" { Disable-RDPUDP }
        "7" { Disable-SNMP }
        "8" {
            Disable-LLMNR
            Disable-SMBv1
            Update-TLS
            Disable-WeakAuth
            Disable-WSDiscovery
            Disable-RDPUDP
            Disable-SNMP
            break
        }
        default { Write-Log -Message "Invalid choice: $choice" -Echo }
    }
}

Write-Log -Message "All selected configurations have been applied. A restart is recommended for full effect." -Echo
Exit 0