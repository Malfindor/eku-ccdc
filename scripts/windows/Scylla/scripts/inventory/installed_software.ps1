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

# Define registry paths for installed software (64-bit and 32-bit)
$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$softwareList = foreach ($path in $regPaths)
{
    Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
}

# Filter out entries without a DisplayName or with a Publisher starting with "Microsoft"
$thirdPartySoftware = $softwareList | Where-Object
{
    $_.DisplayName -and ($_.Publisher -notlike "Microsoft*")
}

$thirdPartySoftware | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName | Format-Table -AutoSize