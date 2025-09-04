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

Write-Host "`n---Change All Default Passwords---"
$csvPath = "$env:HOMEDRIVE\WindowsHardeningCLI\AD\AD_Passwords.csv"
Write-Warning "This generates new passwords for all users in this Active Directory besides the current Administrator and outputs them into a .csv file at $csvPath"
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Exit 1
}
Write-Log "Change all default passwords script begins, caught errors will be listed before end message if any."
function New-Password
{
    do
    {
        $length = Get-Random -Minimum 12 -Maximum 17
        $characters = @([char[]]("a"[0].."z"[0])+[char[]]("A"[0].."Z"[0])+[char[]]("0"[0].."9"[0])+[char[]]("!@$%^&*()-=_{}[]|:?.~"))
        $new = -join (Get-Random -Count $length -InputObject $characters)
    } until(($new -match "[a-z]") -and ($new -match "[A-Z]") -and ($new -match "[0-9]") -and ($new -match "[!@$%^&*()\-=_{\[\]}|:?.~]"))
    return $new
}
$currentAdmin = $env:USERNAME
$users = Get-ADUser -Filter {SamAccountName -ne $currentAdmin}
"Username,Password" | Out-File -FilePath $csvPath -Force

foreach ($user in $users)
{
    $userName = $user.SamAccountName
    $newPass = New-Password
    try
    {
        Set-ADAccountPassword -Identity $userName -NewPassword (ConvertTo-SecureString $newPass -AsPlainText -Force) -Reset
        "$userName,$newPass" | Out-File -Append -FilePath "$csvPath"
        Write-Host -ForegroundColor Green "Password reset for $($userName)"
    } 
    catch
    {
        Write-Log -Echo Red "Failed to reset password for $userName using $($newPass): $_"
    }
}
Write-Host -ForegroundColor Cyan "Changed passwords saved to $csvPath, errors saved in $logFile"
Write-Log "Change all default passwords script ends, changed passwords saved to: $csvPath."