@echo off
REM ══════════════════════════════════════════════════════════════════
REM AgentDeck One-Click Windows Daemon Launcher
REM ══════════════════════════════════════════════════════════════════
title AgentDeck Control Plane Daemon

cd /d "%~dp0.."

if exist "%USERPROFILE%\.agentdeck\bin\agentdeckd.exe" (
    "%USERPROFILE%\.agentdeck\bin\agentdeckd.exe"
) else if exist "target\release\agentdeckd.exe" (
    "target\release\agentdeckd.exe"
) else (
    echo [AgentDeck] Binary not built yet. Running cargo run --bin agentdeckd...
    cargo run --bin agentdeckd
)
