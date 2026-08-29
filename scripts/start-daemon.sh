#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# AgentDeck User-Session Daemon Launcher (Screen & Camera Enabled)
# ══════════════════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$HOME/.gemini/agentdeck/logs"
PID_FILE="$HOME/.gemini/agentdeck/agentdeckd.pid"
CONFIG_FILE="$ROOT_DIR/agentdeck.toml"
BIN_PATH="$HOME/.local/bin/agentdeckd"

mkdir -p "$LOG_DIR"

if [ ! -f "$BIN_PATH" ]; then
    BIN_PATH="$ROOT_DIR/target/release/agentdeckd"
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "agentdeckd binary not found. Building release binary..."
    cd "$ROOT_DIR"
    cargo build --release
    mkdir -p "$HOME/.local/bin"
    cp "$ROOT_DIR/target/release/agentdeckd" "$HOME/.local/bin/agentdeckd"
    BIN_PATH="$HOME/.local/bin/agentdeckd"
fi

# Stop any running instances first
"$SCRIPT_DIR/stop-daemon.sh" 2>/dev/null || true

echo "Starting AgentDeck Daemon in user session..."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

nohup "$BIN_PATH" --config "$CONFIG_FILE" > "$LOG_DIR/daemon.log" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"

sleep 1

if kill -0 "$NEW_PID" 2>/dev/null; then
    echo "✅ AgentDeck daemon is running (PID: $NEW_PID)"
    echo "📜 Logs: $LOG_DIR/daemon.log"
    curl -s http://127.0.0.1:8765/api/status || true
    echo ""
else
    echo "❌ Failed to start AgentDeck daemon. Check logs at $LOG_DIR/daemon.log"
    exit 1
fi
