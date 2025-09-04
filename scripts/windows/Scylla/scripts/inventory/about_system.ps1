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

$inventoryDir = "$env:HOMEDRIVE\Scylla\Inventory"
mkdir -ErrorAction SilentlyContinue $inventoryDir | Out-Null

$ipv6 = Read-Host "Are you using IPv6? (y/N)" 
$ipv6 = $ipv6 -ilike "y*"

$curTime = Get-Date -Format "yyyyMMdd_HHmmss"
$inventoryFile = "$inventoryDir\inventory_$curTime.txt"
Write-Log "Inventory being stored in $inventoryFile" 

Write-Host "Loading inventory..."

Invoke-Command -ScriptBlock {
    Write-Output "`n<!-- Inventory --!>"
    Write-Output "`n--Operating System Information--`n"
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-Output "`tOS: $($osInfo.Caption)`n"
    Write-Output "`tOS Version: $($osInfo.Version)`n"
    Write-Output "`tWMF Version: $($PSVersionTable.PSVersion)`n"

    $netframeworks = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -EA 0 | Where-Object { $_.PSChildName -Match '^(?!S)\p{L}'} | Select-Object PSChildName, Version
    Write-Output "`t.NET Framework Verisons:"

    foreach($netframework in $netframeworks)
    {
        Write-Output "`t`t$($netframework.PSChildName): $($netframework.Version)"
    }

    Write-Output "`n--Interface Information--"
    $interfaces = Get-NetAdapter

    foreach($interface in $interfaces)
    {
        Write-Output "`n`tInterface $($interface.Name)"
        if($interface.Status -ne 'Disabled')
        {
            Write-Output "`t`tIP Address(es): $((Get-NetIPAddress -InterfaceAlias $interface.Name).IPAddress)"
        } else
        {
            Write-Output "`t`tThis interface is in a disabled state."
        }
        Write-Output "`t`tEthernet Address: $($interface.MacAddress)"
    }

    Write-Output "`n--Port Information--`n"

    if($ipv6)
    {
        $tcpconnections =  Get-NetTCPConnection | Where-Object { $_.State -eq 'Listen' } | Sort-Object LocalPort, LocalAddress
        $udpconnections = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -lt '49152' } | Sort-Object LocalPort, LocalAddress
        $udpephemeral  = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -ge '49152' } | Sort-Object LocalPort, LocalAddress
    }
    else
    {
        $tcpconnections =  Get-NetTCPConnection | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.State -eq 'Listen' } | Sort-Object LocalPort, LocalAddress
        $udpconnections = Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.LocalPort -lt '49152' } | Sort-Object LocalPort, LocalAddress
        $udpephemeral  = Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.LocalPort -ge '49152' } | Sort-Object LocalPort, LocalAddress
    }

    foreach($tcpconnection in $tcpconnections)
    {
        $process = Get-Process -Id $tcpconnection.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            LocalAddress = $tcpconnection.LocalAddress
            LocalPort = $tcpconnection.LocalPort
            ProcessName = $process.Name
        }
    }

    Write-Output "^^^^^^^^^ TCP ^^^^^^^^^"

    foreach($udpconnection in $udpconnections)
    {
        $process = Get-Process -Id $udpconnection.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            LocalAddress = $udpconnection.LocalAddress
            LocalPort = $udpconnection.LocalPort
            ProcessName = $process.Name
        }
    }

    Write-Output "^^^^^^^^^ UDP ^^^^^^^^^"

    $connections = $tcpconnections + $udpconnections
    $portsopen = ($connections | Select-Object -Unique LocalPort).Count

    Write-Output "`nTotal unique open ports: $($portsopen)"
    Write-Output "`nEphemeral  UDP ports open: $($udpephemeral.Count)`n"

    Write-Output "For a list of potential vulnerabilities, visit https://www.cvedetails.com."
    Write-Output "If searching via vendor, all Windows operating systems are under Microsoft."
    Write-Output "If searching via product, exclude the Windows edition (such as Standard or Home) when searching (i.e. search `"Windows Server 2012`").`n"
} | Out-File $inventoryFile -Encoding UTF8

Write-Host "Sucess, inventory saved in $inventoryFile"
Write-Log "Sucess, inventory saved in $inventoryFile"
Exit 0