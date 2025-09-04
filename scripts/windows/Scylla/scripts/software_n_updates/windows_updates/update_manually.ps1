#Requires -Version 5.1 -RunAsAdministrator
<#
.SYNOPSIS
A script that will update the Windows OS manually via either:
    1. A .csv file containing hyperlinks to the Microsoft Update Catalog
    2. A directory containing .msu installers
This script can be useful when either:
    - The OS version does not offer cumulative updates
    - The system is air-gapped or is not finding updates on its own
    - The system is being prepared for penetration testing/experimentation with certain patches
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

# Prompt for operational mode
Write-Host "Choose mode:`n1. CSV of Microsoft Update Catalog links (Online)`n2. Staged updates (Offline)`n3. Quit"
$mode = Read-Host "Your selection"

# Set variables based on mode
switch ($mode) {
    "1"
    {
        # Connected environment
        # Inform user of CSV format requirements
        Write-Host "`nEnsure the CSV has headers 'UpdateName' and 'Hyperlinks' (for non-air-gapped mode)."
        $csvList = Read-Host "Enter the literal path for the CSV file (e.g., $env:HOMEDRIVE\path\to\file.csv)"
        if (!(Test-Path $csvList) -or ([System.IO.Path]::GetExtension($csvList) -ne ".csv"))
        {
            Write-Host "`nInvalid file path or type. Ensure it is a valid .csv file."
            Exit 2
        }
        $updateHyperlinks = Import-Csv -LiteralPath $csvList

        # Validate CSV headers
        if (($updateHyperlinks[0].PSObject.Properties.Name -notcontains "UpdateName") -or ($updateHyperlinks[0].PSObject.Properties.Name -notcontains "Hyperlinks"))
        {
            Write-Host "`nIncorrect CSV headers. Ensure they are 'UpdateName' and 'Hyperlinks'."
            Exit 2
        }
    }
    "2"
    {
        # Air-gapped environment
        $localUpdatePath = Read-Host "Enter the path to the directory containing pre-downloaded updates"
        if (!(Test-Path $localUpdatePath))
        {
            Write-Host "`nInvalid path. Ensure the directory exists."
            Exit 2
        }
    }
    "3"
    {
        Write-Host "`nExiting"
        Exit 1
    }
    default
    {
        Write-Host "`nInvalid choice. Exiting."
        Exit 2
    }
}

# Get the list of installed hotfix IDs
$installedHotfixIDs = (Get-Hotfix).HotfixID
Write-Host "`nInstalled hotfixes:"
$installedHotfixIDs | ForEach-Object { Write-Host $_ }

# Filter updates based on mode
if ($mode -eq "1")
{
    # Connected environment: Check for updates not already installed
    $newUpdates = $updateHyperlinks | Where-Object { !($_.UpdateName -in $installedHotfixIDs) }

    if ($newUpdates.Count -eq 0)
    {
        Write-Host "`nNo new updates found in the CSV."
        Exit 0
    }

    # Confirm action
    Write-Host "`nThe following updates are not installed:"
    $newUpdates | ForEach-Object { Write-Host $_.UpdateName }
    $proceed = Read-Host "`nProceed to download and install these updates? (y/N)"
    if ($proceed -notlike "y*")
    {
        Write-Host "Operation cancelled."
        Exit 1
    }

    # Download and install updates
    $tempDir = "$env:temp\scyllaUpdates"
    if (-not (Test-Path $tempDir))
    { 
        mkdir -ErrorAction SilentlyContinue $tempDir | Out-Null
    }
    $webClient = New-Object System.Net.WebClient

    foreach ($link in $newUpdates)
    {
        try
        {
            $filePath = "$tempDir\$($link.UpdateName).msu"
            Write-Host "`nDownloading $($link.UpdateName)..."
            $webClient.DownloadFile($link.Hyperlinks, $filePath)

            Write-Host "Installing $($link.UpdateName)..."
            Start-Process -FilePath "wusa.exe" -ArgumentList $filePath, "/quiet", "/norestart" -Wait
        }
        catch
        {
            Write-Host "Error downloading or installing $($link.UpdateName): $_"
        }
    }
    $webClient.Dispose()
    Remove-Item $tempDir -Recurse -Force
} 
elseif ($mode -eq "2")
{
    # Air-gapped environment: Install updates from the local directory
    $localUpdates = Get-ChildItem -Path $localUpdatePath -Filter *.msu

    if ($localUpdates.Count -eq 0)
    {
        Write-Host "`nNo .msu files found in the specified directory."
        Exit 1
    }

    # Install updates not already installed
    foreach ($updateFile in $localUpdates)
    {
        $updateName = [System.IO.Path]::GetFileNameWithoutExtension($updateFile.Name)
        if ($updateName -in $installedHotfixIDs)
        {
            Write-Host "`nSkipping already installed update: $updateName"
            Continue
        }

        Write-Host "`nInstalling $updateName..."
        Start-Process -FilePath "wusa.exe" -ArgumentList $updateFile.FullName, "/quiet", "/norestart" -Wait
    }
}

# Final steps
$restart = Read-Host "`nUpdates complete. Restart now? (y/N)"
if ($restart -ilike "y*")
{
    Write-Log -Echo Red "Restarting Computer!"
    Start-Sleep 2
    Restart-Computer
}
else
{
    Write-Log -NoDate -Echo Red "Note: A restart is required for updates to take effect."
    Exit 0
}
