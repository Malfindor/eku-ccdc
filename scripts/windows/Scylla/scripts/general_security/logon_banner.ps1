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

Write-Warning "This will set up a notice of the terms of use of using this resource at logon."
$warning = Read-Host "Are you sure you want to continue? (y/N)"
if ($warning -inotlike "y*")
{
    Exit 1
}
Write-Host "Would you like to..."
Write-Host "1. Write your own policy"
Write-Host "2. Use generic terms of use"
$termsChoice = Read-Host "Your selection"
switch($termsChoice)
{
    "1"
    {
        do
        {
            $legalNoticeCaption = Read-Host "Enter the legal notice caption (header)"
            $confirm = Read-Host "The header reads the following: `n$legalNoticeCaption`nWould you like to continue? (y/N)"
        } while ($confirm -inotlike "y*")
        do
        {
            $legalNoticeText = Read-Host "Enter the legal notice text (Use ``n for newline)"
            $confirm = Read-Host "The text reads the following (``n will be replaced): `n$legalNoticeText`nWould you like to continue? (y/N)"
        } while ($confirm -inotlike "y*")
    
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($legalNoticeText)
        $oldSequence = [byte[]](0x60, 0x00, 0x6E, 0x00)
        $newSequence = [byte[]](0x0D, 0x00)
        $modifiedBytes = New-Object System.Collections.Generic.List[byte]
        $index = 0
        while ($index -lt $bytes.Length)
        {
            if ($bytes[$index] -eq $oldSequence[0] -and $bytes[$index+1] -eq $oldSequence[1] -and $bytes[$index+2] -eq $oldSequence[2] -and $bytes[$index+3] -eq $oldSequence[3])
            {
                $modifiedBytes.AddRange($newSequence)
                $index += 4
            }
            else 
            {
                $modifiedBytes.Add($bytes[$index])
                $index++
            }
        }
        $modifiedBytesArray = $modifiedBytes.ToArray()
        $legalNoticeText = [System.Text.Encoding]::Unicode.GetString($modifiedBytesArray)
        Write-Host "Setting logon banner..."
        reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticecaption /t REG_SZ /d "$legalNoticeCaption"
        reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticetext /t REG_SZ /d "$legalNoticeText"
    }
    "2"
    {
        do
        {
            $domainName = Read-Host "What is the name of the domain that you would like to use?"
            $confirm = Read-Host "The domain name is: $domainName`nWould you like to continue? (y/N)"
        } while ($confirm -inotlike "y*")
        Write-Host "Setting logon banner..."
        reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticecaption /t REG_SZ /d "IMPORANT LEGAL NOTICE:"
        reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticetext /t REG_SZ /d "By accessing this resource, you consent to monitoring of your activities and understand $domainName may exercise its rights under the law to access, use, and disclose any information obtained from your use of this resource."
    }
    default
    {
        Write-Host "Invalid selection"
    }
}
Exit 0