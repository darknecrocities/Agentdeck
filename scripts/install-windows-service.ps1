# ══════════════════════════════════════════════════════════════════
# AgentDeck Automated Windows Setup & Background Service Provisioning
# ══════════════════════════════════════════════════════════════════
# Run in PowerShell (as Administrator for Firewall rules, or Standard User for user task)
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\install-windows-service.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       AGENTDECK WINDOWS AUTOMATED PROVISIONING & SERVICE      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

$InstallDir = Join-Path $env:USERPROFILE ".agentdeck\bin"
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 1. Build optimized release binaries
Write-Host "[1/6] Building release binaries (agentdeckd + agentdeck)..." -ForegroundColor Yellow
if (Get-Command "cargo" -ErrorAction SilentlyContinue) {
    cargo build --release
} else {
    Write-Host "Error: Cargo / Rust is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Rust from https://rustup.rs" -ForegroundColor Red
    Exit 1
}

# 2. Copy binaries to ~/.agentdeck/bin
Write-Host "[2/6] Installing binaries to $InstallDir..." -ForegroundColor Yellow
Copy-Item "target\release\agentdeckd.exe" -Destination "$InstallDir\agentdeckd.exe" -Force
Copy-Item "target\release\agentdeck.exe" -Destination "$InstallDir\agentdeck.exe" -Force

# Add ~/.agentdeck/bin to User PATH if not already present
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
    Write-Host "Added $InstallDir to User PATH environment variable." -ForegroundColor Green
}

# 3. Establish secure credentials & .env configuration
Write-Host "[3/6] Configuring .env environment variables..." -ForegroundColor Yellow
$EnvFile = Join-Path $RootDir ".env"
if (!(Test-Path $EnvFile)) {
    $RandomBytes = New-Object byte[] 16
    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($RandomBytes)
    $AuthToken = -join ($RandomBytes | ForEach-Object { "{0:x2}" -f $_ })

    if (Test-Path ".env.example") {
        Copy-Item ".env.example" -Destination $EnvFile
        (Get-Content $EnvFile) -replace "agentdeck-dev-token-change-me", $AuthToken | Set-Content $EnvFile
    } else {
        @"
AGENTDECK_SERVER_HOST=0.0.0.0
AGENTDECK_SERVER_PORT=8765
AGENTDECK_SECURITY_REQUIRE_AUTH=false
AGENTDECK_SECURITY_AUTH_TOKEN=$AuthToken
"@ | Set-Content $EnvFile
    }
    Write-Host "Generated new secure auth token in .env" -ForegroundColor Green
}

# 4. Detect Tailscale for Windows Private Mesh Network
Write-Host "[4/6] Checking Tailscale for Private Mesh Remote Access..." -ForegroundColor Yellow
$TailscaleIP = $null

# Check if Tailscale CLI is available
$TsCmd = Get-Command "tailscale.exe" -ErrorAction SilentlyContinue
if (!$TsCmd) {
    $TsDefaultPath = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $TsDefaultPath) {
        $TsCmd = $TsDefaultPath
    }
}

if ($TsCmd) {
    try {
        $TsIPOutput = & $TsCmd ip -4 2>$null
        if ($TsIPOutput -match "^100\.\d+\.\d+\.\d+") {
            $TailscaleIP = $TsIPOutput.Trim()
        }
    } catch {}
}

# Fallback: Query network interface
if (!$TailscaleIP) {
    $NetAdapter = Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($NetAdapter) {
        $TailscaleIP = $NetAdapter.IPAddress
    }
}

if ($TailscaleIP) {
    Write-Host "Tailscale IP detected: $TailscaleIP" -ForegroundColor Green
} else {
    Write-Host "Tailscale not detected yet. You can install Tailscale for Windows from https://tailscale.com" -ForegroundColor Yellow
}

# 5. Configure Windows Firewall rule for TCP Port 8765
Write-Host "[5/6] Configuring Windows Firewall rule for port 8765..." -ForegroundColor Yellow
try {
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($IsAdmin) {
        netsh advfirewall firewall delete rule name="AgentDeck Daemon" >$null 2>&1
        netsh advfirewall firewall add rule name="AgentDeck Daemon" dir=in action=allow protocol=TCP localport=8765 >$null 2>&1
        Write-Host "Firewall rule created for port 8765." -ForegroundColor Green
    } else {
        Write-Host "Skipping Firewall rule (run as Admin if external devices cannot connect)." -ForegroundColor DarkGray
    }
} catch {}

# 6. Register Windows Scheduled Task for 24/7 background auto-start on logon
Write-Host "[6/6] Registering Windows Auto-Start Background Service (Scheduled Task)..." -ForegroundColor Yellow
$TaskName = "AgentDeckDaemon"
$DaemonExe = "$InstallDir\agentdeckd.exe"

# Stop existing instance if running
Stop-Process -Name "agentdeckd" -Force -ErrorAction SilentlyContinue

# Create scheduled task running under current user without popping up a console window
$Action = New-ScheduledTaskAction -Execute "$DaemonExe" -WorkingDirectory "$RootDir"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Unregister old task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register new task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "AgentDeck Control Plane Background Daemon" | Out-Null

# Start the background task now
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

# Verify Health
$Healthy = $false
try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:8765/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($res.status -eq "ok") {
        $Healthy = $true
    }
} catch {}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "     AGENTDECK WINDOWS SERVICE INSTALLED & STARTED!            " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "• Daemon Binary:    $DaemonExe" -ForegroundColor White
Write-Host "• Status:           $([string]::Concat($(if ($Healthy) {'[RUNNING - HEALTHY]'} else {'[STARTING]'})))" -ForegroundColor $(if ($Healthy) {'Green'} else {'Yellow'})
Write-Host "• Local URL:        http://127.0.0.1:8765" -ForegroundColor Cyan
if ($TailscaleIP) {
    Write-Host "• Phone Connect:    http://$($TailscaleIP):8765" -ForegroundColor Green
} else {
    Write-Host "• Phone Connect:    http://<tailscale-ip>:8765" -ForegroundColor Yellow
}
Write-Host "• Scheduled Task:   $TaskName (Auto-starts whenever you open your laptop)" -ForegroundColor White
Write-Host ""
