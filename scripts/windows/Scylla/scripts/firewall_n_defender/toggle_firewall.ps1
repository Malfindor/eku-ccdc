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

Write-Warning "This will enable the firewall on all profiles with default/already established rules."
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Break
}

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Write-Log "Firewall enabled on all profiles with default/already established rules"

Exit 0