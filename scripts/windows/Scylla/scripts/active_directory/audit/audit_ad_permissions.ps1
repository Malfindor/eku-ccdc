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

$queryLocal = @"
SELECT * FROM __InstanceCreationEvent WITHIN 5 
WHERE TargetInstance ISA 'Win32_NTLogEvent'
  AND TargetInstance.Logfile = 'Security'
  AND TargetInstance.EventIdentifier = '4738'
"@

$queryAD = @"
SELECT * FROM __InstanceCreationEvent WITHIN 5 
WHERE TargetInstance ISA 'Win32_NTLogEvent'
  AND TargetInstance.Logfile = 'Directory Service'
  AND TargetInstance.EventIdentifier = '5136'
"@

$subLocal = Register-WmiEvent -Query $queryLocal -Action {
    $evt = $Event.SourceEventArgs.NewEvent.TargetInstance
    Write-Host "===== LOCAL USER CHANGE DETECTED =====" -ForegroundColor Cyan
    Write-Host "Time Generated:" $evt.TimeGenerated
    Write-Host "Event ID      :" $evt.EventIdentifier
    Write-Host "Message       :" $evt.Message
    Write-Host "=======================================" -ForegroundColor Cyan
} -MessageData "LocalUserChangeAudit"

$subAD = Register-WmiEvent -Query $queryAD -Action {
    $evt = $Event.SourceEventArgs.NewEvent.TargetInstance
    
    Write-Host "===== ACTIVE DIRECTORY CHANGE DETECTED =====" -ForegroundColor Yellow
    Write-Host "Time Generated:" $evt.TimeGenerated
    Write-Host "Event ID      :" $evt.EventIdentifier
    Write-Host "Message       :" $evt.Message
    Write-Host "============================================" -ForegroundColor Yellow
} -MessageData "ADUserChangeAudit"

Write-Host "Monitoring for local and Active Directory user permission changes..."
Write-Host "Press any key to exit and unregister the event subscriptions."
# Keep the script active until a key is pressed
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Unregister-Event -SubscriptionId $subLocal.Id
Unregister-Event -SubscriptionId $subAD.Id
Remove-Job -Id $subLocal.Job.Id -Force
Remove-Job -Id $subAD.Job.Id -Force