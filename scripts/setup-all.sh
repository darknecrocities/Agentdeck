#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# AgentDeck Automated Setup & Remote Control Plane Configuration
# ══════════════════════════════════════════════════════════════════
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          AGENTDECK AUTOMATED SETUP & REMOTE PROVISIONING      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# 1. Build release binaries
echo -e "${YELLOW}[1/5] Building optimized release binaries (agentdeckd + agentdeck)...${NC}"
export PATH="/opt/homebrew/bin:$PATH"
cargo build --release

# 2. Install binaries to /usr/local/bin if writable or ~/.local/bin
echo -e "${YELLOW}[2/5] Installing and code-signing binaries...${NC}"
mkdir -p "$HOME/.local/bin"
cp target/release/agentdeckd "$HOME/.local/bin/agentdeckd"
cp target/release/agentdeck "$HOME/.local/bin/agentdeck"

# On macOS, compile and sign hardware screen and camera streamer helpers with embedded Bundle IDs
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "$SCRIPT_DIR/screen_streamer.m" ]; then
        clang -O2 -fmodules -framework ScreenCaptureKit -framework CoreMedia -framework CoreVideo -framework CoreImage -framework ImageIO -framework CoreGraphics \
          -sectcreate __TEXT __info_plist "$SCRIPT_DIR/screen_streamer_info.plist" \
          "$SCRIPT_DIR/screen_streamer.m" -o "$HOME/.local/bin/agentdeck-screen-streamer"
        codesign --force --deep --sign - --identifier "com.agentdeck.screenstreamer" "$HOME/.local/bin/agentdeck-screen-streamer" 2>/dev/null || true
        cp "$HOME/.local/bin/agentdeck-screen-streamer" "$SCRIPT_DIR/agentdeck-screen-streamer" 2>/dev/null || true
    fi
    if [ -f "$SCRIPT_DIR/camera_streamer.m" ]; then
        clang -O2 -fmodules -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework CoreImage -framework ImageIO -framework CoreGraphics \
          -sectcreate __TEXT __info_plist "$SCRIPT_DIR/camera_streamer_info.plist" \
          "$SCRIPT_DIR/camera_streamer.m" -o "$HOME/.local/bin/agentdeck-camera-streamer"
        codesign --force --deep --sign - --identifier "com.agentdeck.camerastreamer" "$HOME/.local/bin/agentdeck-camera-streamer" 2>/dev/null || true
        cp "$HOME/.local/bin/agentdeck-camera-streamer" "$SCRIPT_DIR/agentdeck-camera-streamer" 2>/dev/null || true
    fi
    codesign --force --deep --sign - "$HOME/.local/bin/agentdeckd" 2>/dev/null || true
fi

# 3. Check or Install Tailscale for Remote Online Access
echo -e "${YELLOW}[3/5] Checking Tailscale for Private Mesh Remote Access...${NC}"
if ! command -v tailscale &> /dev/null && [ ! -d "/Applications/Tailscale.app" ]; then
    echo -e "${CYAN}Installing Tailscale via Homebrew for secure remote phone-to-Mac connectivity...${NC}"
    brew install tailscale || echo -e "${YELLOW}You can also install the Mac App Store Tailscale app if preferred.${NC}"
fi

# 4. Generate Auth Token if not set
echo -e "${YELLOW}[4/5] Establishing secure credentials and .env configuration...${NC}"
if [ ! -f .env ]; then
    AUTH_TOKEN=$(openssl rand -hex 16)
    cp .env.example .env
    sed -i '' "s/agentdeck-dev-token-change-me/$AUTH_TOKEN/" .env 2>/dev/null || true
    echo -e "${GREEN}Generated new secure auth token in .env${NC}"
fi

# 5. Install launchd 24/7 background service
echo -e "${YELLOW}[5/5] Installing macOS background service (auto-start on boot)...${NC}"
"$SCRIPT_DIR/install-macos-service.sh"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}       AGENTDECK REMOTE SETUP COMPLETED SUCCESSFULLY!          ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Run doctor
"$HOME/.local/bin/agentdeck" doctor
