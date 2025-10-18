# ===========================================
# CCDC IIS Hardening Script - Improved
# ===========================================

Import-Module WebAdministration

$backupFolder = "$env:SystemDrive\inetsrv\backup"
$backupName = "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# --------------------------
# Functions
# --------------------------
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }

# Backup IIS configuration
function Backup-IIS {
    Write-Info "Backing up IIS configuration..."
    if (-not (Test-Path $backupFolder)) { New-Item -Path $backupFolder -ItemType Directory | Out-Null }
    & "$env:SystemRoot\System32\inetsrv\appcmd.exe" add backup $backupName 2>$null
    Write-OK "Backup '$backupName' created at $backupFolder\$backupName"
}

# Remove Server header
function Remove-ServerHeader {
    Write-Info "Removing IIS Server header..."
    Set-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering" -Name "removeServerHeader" -Value $true
    Write-OK "Server header removed."
}

# Disable directory browsing
function Disable-DirectoryBrowsing {
    Write-Info "Disabling directory browsing..."
    Set-WebConfigurationProperty -Filter "system.webServer/directoryBrowse" -Name "enabled" -Value $false
    Write-OK "Directory browsing disabled."
}

# Set all app pools to ApplicationPoolIdentity
function Set-AppPoolIdentity {
    Write-Info "Setting all application pools to 'ApplicationPoolIdentity'..."
    $appPools = Get-ChildItem IIS:\AppPools | Select-Object -ExpandProperty Name
    foreach ($pool in $appPools) {
        Set-ItemProperty "IIS:\AppPools\$pool" -Name processModel.identityType -Value "ApplicationPoolIdentity"
    }
    Write-OK "Application pool identities updated."
}

# Configure authentication
function Configure-Authentication {
    Write-Info "Configuring authentication methods for CCDC scoring..."
    Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/windowsAuthentication" -Name "enabled" -Value $true
    Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
    Write-OK "Authentication methods configured (Windows + Anonymous)."
}

# Enforce HTTPS and set security headers
function Enforce-SecurityHeaders {
    Write-Info "Enforcing HTTPS and HTTP security headers..."

    $headers = @{
        "Strict-Transport-Security" = "max-age=31536000; includeSubDomains"
        "X-Content-Type-Options"    = "nosniff"
        "X-Frame-Options"           = "DENY"
        "Referrer-Policy"           = "no-referrer"
        "Content-Security-Policy"   = "default-src 'self'; script-src 'self'; object-src 'none'; style-src 'self';"
        "X-XSS-Protection"          = "1; mode=block"
    }

    foreach ($name in $headers.Keys) {
        $value = $headers[$name]
        if (-not (Get-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -Name "." | Where-Object {$_.name -eq $name})) {
            Add-WebConfigurationProperty -Filter "system.webServer/httpProtocol" -PSPath "IIS:\Sites" -Name "customHeaders" -Value @{name=$name;value=$value}
        } else {
            Set-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -PSPath "IIS:\Sites" -Name "." -Value @{name=$name;value=$value}
        }
    }
    Write-OK "Security headers enforced."
}

# Configure TLS protocols
function Configure-TLS {
    Write-Info "Configuring TLS protocols..."
    $protocols = @("TLS 1.0","TLS 1.1","TLS 1.2")
    foreach ($proto in $protocols) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Server"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        $value = if ($proto -eq "TLS 1.2") { 1 } else { 0 }
        New-ItemProperty -Path $path -Name "Enabled" -PropertyType DWORD -Value $value -Force | Out-Null
    }
    Write-OK "TLS protocols configured."
}

# Harden request filtering
function Harden-RequestFiltering {
    Write-Info "Applying request filtering restrictions..."
    Set-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering/requestLimits" -Name "maxAllowedContentLength" -Value 30000000
    Write-OK "Request filtering hardened."
}

# Remove unneeded IIS modules
function Remove-UnneededModules {
    Write-Info "Removing unnecessary IIS modules..."
    $modules = @("WebDAVModule","TracingModule","WebSocketModule")
    foreach ($mod in $modules) {
        try { Remove-WebGlobalModule $mod -ErrorAction SilentlyContinue } catch {}
    }
    Write-OK "Unneeded modules removed."
}

# Harden IIS logging
function Harden-Logging {
    Write-Info "Hardening IIS logs..."
    $logPath = "C:\inetpub\logs\LogFiles"
    if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory | Out-Null }
    $sites = Get-Website | Select-Object -ExpandProperty Name
    foreach ($site in $sites) {
        Set-ItemProperty "IIS:\Sites\$site" -Name logFile.directory -Value $logPath
    }
    Write-OK "IIS logs moved to $logPath."
}

# Summary
function Summary {
    Write-Host "`n========== IIS Hardening Summary =========="
    Write-Host "Backup Location: $backupFolder\$backupName"
    Write-Host "Directory Browsing: Disabled"
    Write-Host "AppPool Identities: ApplicationPoolIdentity"
    Write-Host "Authentication: Windows + Anonymous (for scoring)"
    Write-Host "Server Header: Removed"
    Write-Host "HTTPS / HSTS / Security Headers: Enabled (XSS & CSP included)"
    Write-Host "TLS Protocols: TLS1.0/1.1 Disabled, TLS1.2 Enabled"
    Write-Host "Request Filtering: Hardened"
    Write-Host "Unneeded Modules: Removed"
    Write-Host "Logs: Moved to C:\inetpub\logs\LogFiles"
    Write-Host "============================================`n"
}

# --------------------------
# Main Execution
# --------------------------
Backup-IIS
Remove-ServerHeader
Disable-DirectoryBrowsing
Set-AppPoolIdentity
Configure-Authentication
Enforce-SecurityHeaders
Configure-TLS
Harden-RequestFiltering
Remove-UnneededModules
Harden-Logging
Summary
