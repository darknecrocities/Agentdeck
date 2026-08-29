@echo off
REM ══════════════════════════════════════════════════════════════════
REM AgentDeck One-Click Windows Setup & Service Installer
REM ══════════════════════════════════════════════════════════════════
title AgentDeck Windows Setup

echo ===============================================================
echo     Starting AgentDeck Automated Windows Service Setup...
echo ===============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows-service.ps1"

echo.
pause
