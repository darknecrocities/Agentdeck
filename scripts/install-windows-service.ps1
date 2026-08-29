# ══════════════════════════════════════════════════════════════════
# AgentDeck Automated Windows Setup & Background Service Provisioning
# ══════════════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "       AGENTDECK WINDOWS AUTOMATED PROVISIONING AND SERVICE    " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

$InstallDir = Join-Path $env:USERPROFILE ".agentdeck\bin"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 0. Trust repository directory and terminate any existing daemon processes
try { git config --global --add safe.directory * } catch {}
Stop-Process -Name "agentdeckd" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "agentdeck" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 600

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
Stop-Process -Name "agentdeckd" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "agentdeck" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Copy-Item "target\release\agentdeckd.exe" -Destination (Join-Path $InstallDir "agentdeckd.exe") -Force
Copy-Item "target\release\agentdeck.exe" -Destination (Join-Path $InstallDir "agentdeck.exe") -Force

# Add ~/.agentdeck/bin to User PATH if not already present
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    $NewUserPath = "$UserPath;$InstallDir"
    [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
    $env:Path = "$env:Path;$InstallDir"
    Write-Host "Added $InstallDir to User PATH environment variable." -ForegroundColor Green
}

# Auto-check and provision FFmpeg for Camera & Media Streaming
$FfmpegExe = Join-Path $InstallDir "ffmpeg.exe"
if (-not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue) -and -not (Test-Path $FfmpegExe)) {
    Write-Host "Checking / Installing FFmpeg for live webcam and streaming..." -ForegroundColor Yellow
    $Installed = $false
    try {
        if (Get-Command "winget" -ErrorAction SilentlyContinue) {
            Write-Host "Installing Gyan.FFmpeg via winget..." -ForegroundColor Cyan
            winget install --id Gyan.FFmpeg -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
            $Installed = $true
        }
    } catch {}
    if (-not $Installed -and -not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {
        try {
            Write-Host "Downloading standalone portable FFmpeg..." -ForegroundColor Cyan
            $ZipPath = Join-Path $env:TEMP "ffmpeg.zip"
            Invoke-WebRequest -Uri "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile $ZipPath -UseBasicParsing
            Expand-Archive -Path $ZipPath -DestinationPath (Join-Path $env:TEMP "ffmpeg_extracted") -Force
            $FoundFfmpeg = Get-ChildItem -Path (Join-Path $env:TEMP "ffmpeg_extracted") -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
            if ($FoundFfmpeg) {
                Copy-Item $FoundFfmpeg.FullName -Destination $FfmpegExe -Force
                Write-Host "FFmpeg installed to $FfmpegExe" -ForegroundColor Green
            }
            Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:TEMP "ffmpeg_extracted") -Recurse -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

# 3. Establish secure credentials & .env configuration
Write-Host "[3/6] Configuring .env environment variables..." -ForegroundColor Yellow
$EnvFile = Join-Path $RootDir ".env"
if (-not (Test-Path $EnvFile)) {
    $RandomBytes = New-Object byte[] 16
    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($RandomBytes)
    $AuthToken = -join ($RandomBytes | ForEach-Object { "{0:x2}" -f $_ })

    if (Test-Path ".env.example") {
        Copy-Item ".env.example" -Destination $EnvFile
        (Get-Content $EnvFile) -replace "agentdeck-dev-token-change-me", $AuthToken | Set-Content $EnvFile
    } else {
        $EnvContent = "AGENTDECK_HOST=0.0.0.0`nAGENTDECK_PORT=8765`nAGENTDECK_REQUIRE_AUTH=false`nAGENTDECK_AUTH_TOKEN=$AuthToken"
        Set-Content -Path $EnvFile -Value $EnvContent
    }
    Write-Host "Generated new secure auth token in .env" -ForegroundColor Green
}

# 4. Detect Tailscale for Windows Private Mesh Network
Write-Host "[4/6] Checking Tailscale for Private Mesh Remote Access..." -ForegroundColor Yellow
$TailscaleIP = $null

$TsCmd = Get-Command "tailscale.exe" -ErrorAction SilentlyContinue
if (-not $TsCmd) {
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

if (-not $TailscaleIP) {
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
$DaemonExe = Join-Path $InstallDir "agentdeckd.exe"

Stop-Process -Name "agentdeckd" -Force -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute "$DaemonExe" -WorkingDirectory "$RootDir"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "AgentDeck Control Plane Background Daemon" | Out-Null

Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

$Healthy = $false
try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:8765/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($res.status -eq "ok") {
        $Healthy = $true
    }
} catch {}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "     AGENTDECK WINDOWS SERVICE INSTALLED AND STARTED!          " -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Daemon Binary:    $DaemonExe" -ForegroundColor White
if ($Healthy) {
    Write-Host "Status:           [RUNNING - HEALTHY]" -ForegroundColor Green
} else {
    Write-Host "Status:           [STARTING]" -ForegroundColor Yellow
}
Write-Host "Local URL:        http://127.0.0.1:8765" -ForegroundColor Cyan
if ($TailscaleIP) {
    Write-Host "Phone Connect:    http://$TailscaleIP:8765" -ForegroundColor Green
} else {
    Write-Host "Phone Connect:    http://<tailscale-ip>:8765" -ForegroundColor Yellow
}
Write-Host "Scheduled Task:   $TaskName (Auto-starts whenever you open your laptop)" -ForegroundColor White
Write-Host ""
