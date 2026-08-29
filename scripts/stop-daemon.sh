#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# AgentDeck Daemon Terminator
# ══════════════════════════════════════════════════════════════════
set -e

PID_FILE="$HOME/.gemini/agentdeck/agentdeckd.pid"

# Unload any launchd service if present
launchctl bootout "gui/$(id -u)/com.agentdeck.daemon" 2>/dev/null || true

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
        echo "Stopped AgentDeck daemon (PID: $OLD_PID)"
    fi
    rm -f "$PID_FILE"
fi

# Also kill any stray agentdeckd processes
pkill -f "agentdeckd" 2>/dev/null || true
pkill -f "ffmpeg -f avfoundation -pixel_format bgr0 -i 1:none" 2>/dev/null || true

echo "AgentDeck daemon stopped."
