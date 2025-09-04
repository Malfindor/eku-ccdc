#Requires -Version 3.0
<#
.SYNOPSIS
Requires PS 3.0, Administrator rights, and .NET 4.5+ on one of the following OS:
    - Windows Server 2012 R2
    - Windows Server 2012
    - Windows 2008 R2 SP1
    - Windows 8.1
    - Windows 7 SP1

.NOTES
Author: Logan Jackson
Date: 2024

.LINK
Website: https://lj-sec.github.io/
#>

param (
    [switch]$NoRestart
)

# PowerShell 3.0 compatible way of checking for admin, requires admin was introduced later
$currentUser = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentUser.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Error "`nYou must run this script as an administrator."
    Exit 1
}

if(MyInvocation.PSCommandPath -notlike "*scylla_core.ps1")
{
    Write-Error "Script not launched from core Scylla script."
    Exit 1
}

if($PSVersionTable.PSVersion.Major -ge "7" -and $PSVersionTable.PSVersion.Minor -ge "4")
{
    Write-Host "WMF is up-to-date, 7.4.x"
}
elseif($PSVersionTable.PSVersion.Major -ge "5" -and $PSVersionTable.PSVersion.Minor -ge "1")
{
    Write-Host "WMF is up-to-date, 5.1.x"
    if(!(Test-Path "$env:ProgramFiles\Powershell\7"))
    {
        $checkUpdateWMF = Read-Host "Would you like to optionally install 7.4.1? (y/N)"
        if($checkUpdateWMF -ilike "n*")
        {
            Write-Host "No problem"
        }
        else
        {
            $updateWmf = $true
            $script:wmfLink = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
        }
    }
}
else
{
    Write-Warning "Powershell is not up-to-date!"
    $updateWmf = Read-Host "WMF 5.1 or later is required. Would you like to update now to 5.1? (Y/n)"
    if($updateWmf -ilike "n*")
    {
        Write-Warning "Powershell 5.1 and later is required for this script!"
        Write-Host "If you would like to run this script anyway (not recommended), rerun with -NoWmf."
        Exit 1
    }
    else
    {
        switch -Wildcard ((Get-CimInstance Win32_OperatingSystem).Caption)
        {
            "*2012 R2*"
                {
                    $updateWmf = $true
                    $script:wmfLink = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/W2K12-KB3191565-x64.msu"
                }
            "*2012*"
                {
                    $updateWmf = $true
                    $script:wmfLink = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu"
                }
            default
                {
                    Write-Warning "Could not fetch link to download WMF 5.1. This script has only been tested on Windows Server 2012 and 2012 R2 as of now."
                    Write-Host "It is highly recommended to install this version yourself."
                }
        }
    }
}
if ($NoRestart -eq $false)
{
    $confirmRestart = Read-Host "Restart now? (y/N)"
    if($confirmRestart -ilike "y*")
    {
        Write-Host "Restarting computer..."
        Start-Sleep 2
        Restart-Computer
    }
}
else
{
    Write-Log -Echo Red "PowerShell is already 5.1+, version: $($PSVersionTable.PSVersion.ToString())"    
}