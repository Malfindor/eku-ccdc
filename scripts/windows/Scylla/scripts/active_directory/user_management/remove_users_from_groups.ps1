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

Write-Warning "This will remove *ALL* groups that *ALL* users (besides this current Admin!) on the AD Domain belong to, reducing them all to `"Domain Users`""
Write-Host "A log of groups that members were previously in will be stored in the $env:HOMEDRIVE\WindowsHardeningCLI\AD directory"
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Break
}
Write-Log "Remove all AD users from groups script begins"

$currentAdmin = $env:USERNAME
$users = Get-ADUser -Filter {SamAccountName -ne $currentAdmin}

$curTime = Get-Date -Format "yyyyMMdd_HHmmss"
$groupLogPath = "$env:HOMEDRIVE\WindowsHardeningCLI\AD\AD_removedgroups_$curTime.txt"
Out-File -FilePath $groupLogPath -Force
"Time Start: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss K")" | Out-File -Append -FilePath $groupLogPath 

foreach ($user in $users)
{
    $userGroups = Get-ADUser $user.SamAccountName | Get-ADPrincipalGroupMembership | Where-Object { $_.SamAccountName -ne "Domain Users" }
    foreach ($group in $userGroups)
    {
        try
        {
            Remove-ADGroupMember -Identity $group.SamAccountName -Members $user.SamAccountName -Confirm:$false
            Write-Host -ForegroundColor Green "Removed $($user.SamAccountName) from group $($group.SamAccountName)"
            "$($user.SamAccountName) was removed from group $($group.SamAccountName)" | Out-File -Append -FilePath $groupLogPath
        }
        catch
        {
            Write-Host -ForegroundColor Red "Failed to remove $($user.SamAccountName) from $(group.SamAccountName): $_"
        }
    }
}

Write-Host -ForegroundColor Cyan "Groups have been removed from all AD users, log saved at: $groupLogPath"
"Time End: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss K")" | Out-File -Append -FilePath $groupLogPath
Write-Log "Remove all AD users from groups script ends"