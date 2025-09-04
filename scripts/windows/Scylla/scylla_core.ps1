#Requires -Version 3.0
<#
.SYNOPSIS
Requires PS 5.1, .NET 4.8, and Administrator rights
Script will update OS to 5.1 and .NET 4.8 from PS 3.0 and 4.5.x if applicable

.NOTES
Author: Logan Jackson
Date: 2024

.LINK
Website: https://lj-sec.github.io/
#>

# PowerShell 3.0 compatible way of checking for admin; requires -runasadministrator was introduced later
$currentUser = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentUser.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Warning "`nYou must run this script as an administrator."
    Exit 1
}

### Setup

# Initialize where scripts are held
$scriptsDir = "$($PSScriptRoot)\scripts"

# Creating a log file to note changes made to the system
$scyllaDir = "$env:HOMEDRIVE\Scylla"
$scyllaLogsDir = "$scyllaDir\Logs"

mkdir -ErrorAction SilentlyContinue $scyllaDir | Out-Null
mkdir -ErrorAction SilentlyContinue $scyllaLogsDir | Out-Null

$curTime = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$scyllaLogsDir\log_$curTime.txt"
Out-File $logFile

### Functions

# Function to append $Message to $logFile
# $NoDate attaches no date to $Message when writing to $logFile
# $Echo can contain a color to write $Message to user
function Write-Log
{
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [switch]$NoDate,
        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
        [string]$Echo = $null
    )

    if($Echo) # Write the $Message to the console in specified color
    {
        Write-Host -ForegroundColor $Echo "`n$Message`n"
    }

    if($NoDate.IsPresent) # Attach no date to the log, useful for script-wide notes
    {
        Write-Output "// $Message" | Out-File $logFile -Append
    }
    else # Grab the current date and attach it to the beginning of the $Message
    {
        $currentTime = Get-Date -Format "MM/dd/yyyy HH:mm:ss K"
        Write-Output "$currentTime - $Message" | Out-File $logFile -Append   
    }
}

# Main functionality of the script;
#   displays menu of subdirectories and .ps1 scripts in $Directory and expects user input as an integer
# Currently will return a path to one of the following:
#   -Subdirectory of $Directory
#   -A .ps1 script in $Directory
#   -$Directory's parent directory
#   -$PSScriptRoot\scripts (main script directory)
#   -$null if user would like to exit script
# Optionally, $Color contains the color of the header of the menu 
function Write-Menu
{
    param (
        [Parameter(Mandatory)]
        [string]$Directory,
        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
        [string]$Color=$null
    )

    # Will loop forever until function issues a return statement
    while ($true)
    {
        if($Color)
        {
            Write-Host -ForegroundColor $Color "`n--- $($Directory | Split-Path -Leaf) ---`n"
        }
        else
        {
            Write-Host "`n--- $($Directory | Split-Path -Leaf) ---`n"
        }
        $index = 1
        $directories = Get-ChildItem -Path $Directory | Where-Object {($_.PSIsContainer) -and ($_.Name -ne ".vscode")}
        $scripts = Get-ChildItem -Path $Directory | Where-Object {($_.Extension -ieq ".ps1") -and ($_.Name -ne "$($PSCommandPath | Split-Path -Leaf)")}

        $directories | ForEach-Object -Process {
            Write-Host -ForegroundColor Blue "$($index): $($_.Name)"
            $index++
        }
        $scripts | ForEach-Object -Process {
            Write-Host -ForegroundColor Cyan "$($index): $($_.Name)"
            $index++
        }

        if($Directory -ne $scriptsDir)
        {
            Write-Host -ForegroundColor DarkYellow "$($index): Parent Directory"
            $index++
            if(($Directory | Split-Path -Parent) -ne $scriptsDir)
            {
                Write-Host -ForegroundColor DarkYellow "$($index): Scylla Root"
                $index++
            }
        }
        Write-Host -ForegroundColor Red "$($index): Quit"

        $selection = Read-Host "`nYour selection"
        if(($selection -as [int]))
        {
            $selection = [int]$selection
            if($selection -le $directories.Count)
            {
                return $directories[$selection - 1].FullName
            }
            elseif (($selection -gt $directories.Count) -and ($selection -le ($directories.Count + $scripts.Count)))
            {
                return $scripts[$selection - $directories.Count - 1].FullName
            }
            elseif ($selection -eq ($index - 2))
            {
                return $Directory | Split-Path -Parent
            }
            elseif ($selection -eq ($index - 1))
            {
                return $scriptsDir
            }
            elseif ($selection -eq $index)
            {
                return $null
            }
        }
        Write-Host -ForegroundColor Red "`nInvalid selection! Please enter a number between 1 and $index"
    }
}

# Will be called if PowerShell version is found to be less than 5.1, executes PowerShell updater found in Scylla
# If .NET version found to be outdated as well, script will be called with -NoRestart to ensure both are updated
function Update-PowerShell
{
    param (
        [switch]$NoRestart
    )
    $script:outdatedPowerShell = $false
    $powershellScriptPath = "$($scriptsDir)\software_n_updates\windows_updates\powershell_updater.ps1"
    if(Test-Path $powershellScriptPath)
    {
        if($NoRestart.IsPresent)
        {
            . $powershellScriptPath -NoRestart
        }
        else
        {
            . $powershellScriptPath
        }
    }
    else
    {
        Write-Error "Powershell Updater script not found and version below 5.1"
        Exit 2
    }
}

# Will be called if .NET version is found to be less than 4.8, executes .NET updater found in Scylla
function Update-DotNet
{
    $dotnetScriptPath = "$($scriptsDir)\software_n_updates\windows_updates\dotnet_updater.ps1"
    if(Test-Path $dotnetScriptPath)
    {
        . $dotnetScriptPath
    }
    else
    {
        Write-Error ".NET Updater script not found and version below 4.8"
        Exit 2
    }
}

# Returns $FilePath's relative path from $PSScriptRoot (the directory of the executing script)
function Get-RelativeToRoot
{
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    $fullPath = Resolve-Path -Path $FilePath
    return ($fullPath -replace [regex]::Escape("$($PSScriptRoot)"), "$($PSScriptRoot | Split-Path -Leaf)")
}

### Start of core script

Write-Log "Core script begins!"

## Version Checking

$script:outdatedPowerShell = $false

# Grab Full .NET version
$dotnet = Get-ItemProperty -ErrorAction SilentlyContinue 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'

# Check if PowerShell is less than 5.1, if so we need to update
if ($PSVersionTable.PSVersion.Major -lt 5 -and $PSVersionTable.PSVersion.Minor -lt 1)
{
    $script:outdatedPowerShell = $true
}

# Check if .NET release is lower than the minimum required to be 4.8
if (!$dotnet -or ($dotnet.Release -lt 528040))
{
    # If PowerShell is outdated as well, update that first without restarting
    if($script:outdatedPowerShell -eq $true)
    {
        Update-PowerShell -NoRestart
    }
    Update-DotNet
    Write-Host "You must restart after update for updates to be applied!"
    Exit 0
}

# If $script:outdatedPowerShell is true means that only PowerShell needs to be updated
if($script:outdatedPowerShell -eq $true)
{
    Update-PowerShell
    Write-Host "You must restart after update for updates to be applied!"
    Exit 0
}

## Splash screen

Clear-Host
Write-Host -ForegroundColor Red @"
`n`n
      ████████████╗███████╗ ██████╗██╗   ██╗██╗     ██╗      █████╗ 
     █  █████████╔╝██╔════╝██╔════╝╚██╗ ██╔╝██║     ██║     ██╔══██╗
    ███  ███████╔╝ ███████╗██║      ╚████╔╝ ██║     ██║     ███████║
   █████  █████╔╝   ════██║██║       ╚██╔╝  ██║     ██║     ██╔══██║
  ███   ███  █╔╝   ███████║╚██████╗   ██║   ███████╗███████╗██║  ██║
 ████████████╔╝    ╚══════╝ ╚═════╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
 ╚═══════════╝ ════════════════════════════════════════════ 02/04/25
`n`n
"@
Write-Host -ForegroundColor DarkYellow "Established a log file at $logFile"

## Main script

# Wrap script in a try/catch/finally to determine how the script eventually exits
try
{
    # Currently for debugging purposes, will handle errors more cleanly in the future
    $ErrorActionPreference = "Stop"
    # $ErrorActionPreference = "SilentlyContinue"

    # Set the current directory to the directory of this script
    $curDir = $scriptsDir

    # Will loop forever until script errors or issues an exit statement on user's choice to quit
    while($true)
    {
        # Do..until statement will Write-Menu until $curDir is $null or not a directory
        do
        {
            $curDir = Write-Menu -Color Magenta -Directory $curDir
        } until (($null -eq $curDir) -or (Test-Path -Path $curDir -PathType Leaf))

        # If $curDir is not $null or a directory, it must contain a .ps1 script by Write-Menu's defintion
        if($curDir)
        {
            # Find and display the path relative to $curDir
            $relToRoot = Get-RelativeToRoot $curDir
            Write-Log -Echo Green "Executing the following script: $($relToRoot)"
            # Execute the .ps1 script $curDir
            try
            {
                . $curDir
                if($LASTEXITCODE -eq 0)
                {
                    Write-Log -Echo Green "$relToRoot has successfully executed!"
                }
                elseif($null -ne $LASTEXITCODE)
                {
                    Write-Log -Echo Yellow "$relToRoot exited with code: $($LASTEXITCODE)"
                }
                else
                {    
                    Write-Log -Echo Yellow "$relToRoot exited with no exit code"
                }
            }
            catch
            {
                Write-Log -Echo Red "$relToRoot failed with terminating error: $_"
            }
            # Return to the menu by setting $curDir to the parent directory of the executed script
            Write-Host -ForegroundColor Red "Returning to menu..."
            $curDir = $curDir | Split-Path -Parent
        }
        else #curDir must be $null, by Write-Menu's defintion, user chooses to exit
        {
            Write-Log -Echo Red "User quitting Scylla! Log file at $logFile"
            # Variable for the finally block to determine that this was a user-chosen exit
            $gracefulExit = $true
            Exit
        }
        # Loop back to the do..until statement
    }
}
catch
{
    $terminatingError = $true
    Write-Log -Echo Red "Terminating error: $_"
}
finally # Finally block will not execute if user closes window in which this script is executing or in similar situations
{
    if($gracefulExit -eq $true)
    {
        Write-Log "Script ends!"
        Exit 0
    }
    elseif($terminatingError -eq $true)
    {
        Write-Log -Echo Red "Script exiting with error. Log file at $logFile"
        Exit 1
    }
    Write-Log -Echo Red "`nScript exiting forcefully (CTRL+C). Log file at $logFile"
    Exit 2
}