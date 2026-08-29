# ══════════════════════════════════════════════════════════════════
# AgentDeck Windows Service Uninstaller
# ══════════════════════════════════════════════════════════════════
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-windows-service.ps1

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "Stopping and removing AgentDeck Windows background service..." -ForegroundColor Yellow

$TaskName = "AgentDeckDaemon"

# Stop running daemon processes
Stop-Process -Name "agentdeckd" -Force
Stop-Process -Name "agentdeck" -Force

# Unregister Scheduled Task
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host "AgentDeck Windows service successfully uninstalled." -ForegroundColor Green
Write-Host ""
