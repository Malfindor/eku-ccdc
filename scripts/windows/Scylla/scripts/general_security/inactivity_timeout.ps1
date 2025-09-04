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

Write-Warning "This will set an inactivity timeout to the amount of seconds specified by you."
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Break
}

$secondsLogout = Read-Host "How many seconds of inactivity before session logout?"
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d $secondsLogout /f