#!/usr/bin/env bash
set -e

PLIST_NAME="com.agentdeck.daemon.plist"
SRC_PLIST="$(dirname "$0")/$PLIST_NAME"
TARGET_DIR="$HOME/Library/LaunchAgents"
LOGS_DIR="$HOME/.gemini/agentdeck/logs"

mkdir -p "$TARGET_DIR" "$LOGS_DIR"
cp "$SRC_PLIST" "$TARGET_DIR/$PLIST_NAME"

launchctl unload "$TARGET_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$TARGET_DIR/$PLIST_NAME"

echo "AgentDeck launchd service installed and loaded successfully!"
echo "Logs: $LOGS_DIR/daemon.log"
