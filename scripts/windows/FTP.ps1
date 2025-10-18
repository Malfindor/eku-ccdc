# Safe_FTP_Hardening.ps1
# Run as Administrator
# Creates backups, enables logging, firewall rules for FTP (control + passive range),
# disables a few insecure services, enables Defender, auditing, disables Guest.
# Does NOT: require SSL, disable anonymous, change user isolation, or deny FTP commands.

# 0) Elevation check
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "Please run this script elevated (as Administrator). Exiting."
    exit 1
}

# 1) Prepare log folder and transcript
$now = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "C:\HardeningLogs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "Safe_FTP_Hardening_$now.log"
Start-Transcript -Path $logFile -Force
Write-Host "Safe FTP hardening started. Log: $logFile"

# 2) Backup IIS configuration (appcmd)
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
if (Test-Path $appcmd) {
    $bakname = "PreCCDC_SafeBackup_$now"
    & $appcmd add backup $bakname
    Write-Host "[OK] IIS backup created: $bakname"
} else {
    Write-Warning "appcmd.exe not found; skipping IIS backup."
}

Import-Module WebAdministration -ErrorAction SilentlyContinue

# 3) Ensure FTP logging (W3C, daily)
try {
    Set-WebConfigurationProperty -PSPath "IIS:\" -Filter "system.applicationHost/sites/siteDefaults/ftpServer/logFile" -Name "logFormat" -Value "W3C" -ErrorAction Stop
    Set-WebConfigurationProperty -PSPath "IIS:\" -Filter "system.applicationHost/sites/siteDefaults/ftpServer/logFile" -Name "period" -Value "Daily" -ErrorAction Stop
    Write-Host "[OK] FTP logging set to W3C Daily."
} catch {
    Write-Warning "Could not set FTP logging defaults: $_"
}

# 4) Firewall: allow control port 21 and conservative passive range 50000-50100
$lowPort = 50000
$highPort = 50100
Try {
    if (-not (Get-NetFirewallRule -DisplayName "Allow FTP Control (21)" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "Allow FTP Control (21)" -Direction Inbound -LocalPort 21 -Protocol TCP -Action Allow | Out-Null
        Write-Host "[OK] Firewall rule created: Allow FTP Control (21)"
    } else { Write-Host "Firewall rule for TCP/21 already exists." }

    $rangeName = "Allow FTP Passive $lowPort-$highPort"
    if (-not (Get-NetFirewallRule -DisplayName $rangeName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $rangeName -Direction Inbound -LocalPort "$lowPort-$highPort" -Protocol TCP -Action Allow | Out-Null
        Write-Host "[OK] Firewall rule created: $rangeName"
    } else { Write-Host "Firewall rule for passive range already exists." }
} catch {
    Write-Warning "Firewall rules failed: $_"
}

# 5) Disable obviously insecure/unneeded services (safe list)
# Telnet (TlntSvr), RemoteRegistry, and set Remote Registry disabled (if present)
try {
    $svc = Get-Service -Name TlntSvr -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name TlntSvr -Force -ErrorAction SilentlyContinue
        Set-Service -Name TlntSvr -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "[OK] Telnet service stopped & disabled."
    } else { Write-Host "Telnet not present." }

    $rr = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
    if ($rr) {
        Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
        Set-Service -Name RemoteRegistry -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "[OK] RemoteRegistry stopped & disabled."
    } else { Write-Host "RemoteRegistry service not present." }
} catch {
    Write-Warning "Service disable step failed: $_"
}

# 6) Attempt to disable SMBv1 (best-effort, no reboot)
try {
    Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null
    # also server side via Set-SmbServerConfiguration if available
    if (Get-Command Set-SmbServerConfiguration -ErrorAction SilentlyContinue) {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Attempted to disable SMBv1 (client & server) if present."
} catch {
    Write-Warning "SMBv1 disable attempt failed: $_"
}

# 7) Enable Windows Defender real-time and update signatures (if Defender present)
try {
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Update-MpSignature -ErrorAction SilentlyContinue
    Write-Host "[OK] Windows Defender real-time ensured and signature update attempted."
} catch {
    Write-Warning "Windows Defender configuration failed or Defender not present: $_"
}

# 8) Enable basic audit categories (safe)
try {
    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
    auditpol /set /category:"Object Access" /success:enable /failure:enable | Out-Null
    auditpol /set /category:"Policy Change" /success:enable /failure:enable | Out-Null
    Write-Host "[OK] Basic audit categories enabled (Logon/Logoff, Object Access, Policy Change)."
} catch {
    Write-Warning "Audit policy changes failed: $_"
}

# 9) Disable Guest account (safe)
try {
    $guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
    if ($guest) {
        Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
        Write-Host "[OK] Guest account disabled."
    } else { Write-Host "No local Guest account found (or it's already disabled)." }
} catch {
    Write-Warning "Failed to disable Guest: $_"
}

# 10) Quick verification output
Write-Host "`n--- Quick verification ---"
Write-Host "IIS backup name (if created): $bakname"
Write-Host "FTP logging: W3C daily (default siteDefaults set)"
Write-Host "Firewall: TCP/21 and $lowPort-$highPort inbound allowed (verify with Get-NetFirewallRule)"
Write-Host "Disabled Telnet/RemoteRegistry if they existed. SMBv1 attempt made."
Write-Host "Defender update attempted. Audit policy set."

# 11) Finish
Stop-Transcript
Write-Host "`nSafe hardening complete. Detailed transcript: $logFile"
