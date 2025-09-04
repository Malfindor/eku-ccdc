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

$dotnet = Get-ItemProperty -ErrorAction SilentlyContinue 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'

if (!$dotnet -or ($dotnet.Release -lt 528040))
{
    Write-Warning ".NET Framework is not 4.8 or above!"
    $updateNet = Read-Host "Would you like to update now? (Y/n)"

    if ($updateNet -ilike "n*")
    {
        Write-Host "Script exiting..."
        Exit 1
    }
    
    Write-Host "Updating .NET to 4.8..."

    try
    {
        Write-Host "Downloading .NET updater..."

        $installerPath = "$env:temp\net-updater.exe"

        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile("https://go.microsoft.com/fwlink/?LinkId=2085155", $installerPath)

        Write-Host "Running .NET updater..."
        Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait

        Write-Host "Done!"
    }
    catch
    {
        Write-Error "Failed to update .NET Framework. Error: $_"
        Exit 2
    } 
    finally
    {
        if (Test-Path $installerPath)
        {
            Remove-Item $installerPath -Force
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
}
else
{
    Write-Log -Echo Red ".NET is already 4.8+, version: $($dotnet.Version)"
}
Exit 0