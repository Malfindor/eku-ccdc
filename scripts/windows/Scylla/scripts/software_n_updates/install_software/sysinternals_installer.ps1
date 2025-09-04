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

Write-Warning "This will attempt to install the Sysinternals Suite to $env:HOMEDRIVE\Sysinternals."
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Break
}

Write-Host "Sysinternals"
if(Test-Path $env:HOMEDRIVE\Windows\SysInternalsSuite)
{
    $switchdirSysinternals = Read-Host "Sysinternals installed at $env:HOMEDRIVE\Windows\Sysinternals. Switch directories now? (y/N)"
    if($switchdirSysinternals -like "y*")
    {
        Set-Location "$env:HOMEDRIVE\Windows\Sysinternals"
        Break
    }
}
elseif(Test-Path $env:HOMEDRIVE\Windows\SysInternalsSuite.zip)
{
    $confirmSysUnzip = Read-Host "Unzip Sysinterals?"
    if($confirmSysUnzip -ilike "y*")
    {
        Expand-Archive -Path $env:HOMEDRIVE\Windows\SysInternalsSuite -DestinationPath $env:HOMEDRIVE\Windows\SysInternalsSuite -Force
    }
}
else
{
    $confirmSysinternals = Read-Host "Sysinternals Suite is not detected, install now? (y/N)"
    $webClient = New-Object System.Net.WebClient
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    if($confirmSysinternals -ilike "y*")
    {
        Write-Host "Installing sysinternals..."
        $webClient.DownloadFile("https://download.sysinternals.com/files/SysinternalsSuite.zip","$env:HOMEDRIVE\Windows\SysInternalsSuite.zip") | Wait-Event
    }
}
Exit 0