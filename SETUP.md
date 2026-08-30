# 🚀 AgentDeck: Open-Source Setup & Deployment Guide

AgentDeck is a local-first, unified AI engineering control plane for autonomous coding agents (Google Antigravity, Claude Code, Gemini CLI, and Ollama). It allows you to monitor, prompt, and control AI coding agents running on your workstation from your mobile phone over an encrypted Tailscale WireGuard mesh with zero public open ports.

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Quickstart in 5 Minutes](#2-quickstart-in-5-minutes)
3. [Tailscale & Workstation Setup Guide](#3-tailscale--workstation-setup-guide)
   - [Tailscale WireGuard Mesh Architecture](#31-tailscale-wireguard-mesh-architecture)
   - [Workstation Node Setup (macOS / Linux / Windows)](#32-workstation-node-setup)
   - [Multi-Node Workstation Fleet Management](#33-multi-node-workstation-fleet-management)
   - [Firewall & Port Binding Rules (Port 8765)](#34-firewall--port-binding-rules-port-8765)
   - [MagicDNS & Auto-Discovery](#35-magicdns--auto-discovery)
   - [USB Debugging Fallback Proxy](#36-usb-debugging-fallback-proxy)
4. [Mobile Client Setup (`agentdeck_mobile`)](#4-mobile-client-setup-agentdeck_mobile)
5. [Supported AI Coding Agents & Engines](#5-supported-ai-coding-agents--engines)
6. [Environment Variables Reference](#6-environment-variables-reference)
7. [Running in the Background as a 24/7 Service](#7-running-in-the-background-as-a-247-service)
8. [Troubleshooting & FAQs](#8-troubleshooting--faqs)

---

## 1. Prerequisites

Before installing AgentDeck, ensure your environment meets the following requirements:

### Workstation Host (macOS / Linux / Windows WSL2)
- **Rust toolchain 1.80+**:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```
- **SQLite 3**: (pre-installed on macOS/Linux; required for local event storage).
- **Tailscale**: (free for personal use, provides peer-to-peer encrypted WireGuard mesh).
  - macOS: `brew install --cask tailscale` or download from [tailscale.com](https://tailscale.com).
  - Linux: `curl -fsSL https://tailscale.com/install.sh | sh`
  - Windows: Download installer from [tailscale.com/download/windows](https://tailscale.com/download/windows).
- **Optional Local LLM Engine (Ollama)**:
  ```bash
  brew install ollama
  ollama run qwen2.5-coder:7b
  ```

### Mobile Development (Android / iOS)
- **Flutter SDK 3.24+**:
  ```bash
  flutter doctor
  ```
- **Android Studio / Xcode**: For compiling Android APK or iOS app.
- **Tailscale App on Mobile**: Install Tailscale from Google Play Store or Apple App Store.

---

## 2. Quickstart in 5 Minutes

### Step 1: Clone the Repository
```bash
git clone https://github.com/darknecrocities/Agentdeck.git
cd Agentdeck
```

### Step 2: Configure Your Environment
```bash
cp .env.example .env
```

### Step 3: Run the Host Daemon
```bash
cargo run --bin agentdeckd
```
The daemon will initialize the SQLite database at `~/.agentdeck/agentdeck.db` and bind to `http://0.0.0.0:8765`.

### Step 4: Run the Mobile App
```bash
cd agentdeck_mobile
flutter pub get
flutter run
```

---

## 3. Tailscale & Workstation Setup Guide

### 3.1 Tailscale WireGuard Mesh Architecture

AgentDeck uses Tailscale WireGuard mesh networking to connect your mobile client to your host workstation(s) with **zero open public ports**, zero port forwarding on home routers, and end-to-end encryption.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Encrypted Tailscale Mesh                        │
│                           (100.64.0.0/10)                              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       ▼                            ▼                            ▼
┌───────────────┐            ┌───────────────┐            ┌──────────────┐
│  Mobile Phone │            │ MacBook Node  │            │ Linux Server │
│ (100.64.1.10) │ <--------> │ (100.64.1.20) │            │ (100.64.1.30)│
│  AgentDeck App│  WireGuard │  agentdeckd   │            │  agentdeckd  │
└───────────────┘   (8765)   └───────────────┘            └──────────────┘
```

#### Why Tailscale WireGuard?
- **Zero Firewall Vulnerabilities**: You never expose your laptop to the public internet or open router ports.
- **Works on Any Network**: Mobile client connects seamlessly whether on 5G/LTE cellular, hotel Wi-Fi, coffee shop networks, or home Wi-Fi.
- **Sub-30ms Peer-to-Peer Latency**: Tailscale establishes direct WireGuard tunnels between devices using DERP STUN hole-punching.

---

### 3.2 Workstation Node Setup

#### 🍏 macOS Workstation Setup
1. Install and authenticate Tailscale:
   ```bash
   brew install --cask tailscale
   tailscale up
   ```
2. Verify node IPv4 address:
   ```bash
   tailscale ip -4
   # Example output: 100.x.y.z
   ```
3. Grant macOS Screen Recording & Accessibility Permissions (for remote screen streaming):
   - Go to **System Settings > Privacy & Security > Screen Recording**.
   - Enable permission for `Terminal`, `iTerm2`, or `agentdeckd`.
4. Build and install release binaries:
   ```bash
   cargo build --release
   mkdir -p ~/.local/bin
   cp target/release/agentdeckd ~/.local/bin/
   cp scripts/agy ~/.local/bin/agy
   chmod +x ~/.local/bin/agy
   ln -sf ~/.local/bin/agy ~/.local/bin/aagy
   ```

#### 🐧 Linux (Ubuntu / Debian / Fedora / Arch) Setup
1. Install and start Tailscale:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   tailscale ip -4
   ```
2. Configure firewall rule for port `8765`:
   ```bash
   # UFW (Ubuntu/Debian)
   sudo ufw allow in on tailscale0 to any port 8765 proto tcp
   # Or allow all Tailscale traffic
   sudo ufw allow in on tailscale0
   ```
3. Build and install:
   ```bash
   cargo build --release
   mkdir -p ~/.local/bin
   cp target/release/agentdeckd ~/.local/bin/
   ```

#### 🪟 Windows Workstation Setup
1. Install Tailscale from [tailscale.com](https://tailscale.com) and log in.
2. In PowerShell (Run as Administrator), configure Windows Defender Firewall:
   ```powershell
   New-NetFirewallRule -DisplayName "AgentDeck Daemon" -Direction Inbound -LocalPort 8765 -Protocol TCP -Action Allow
   ```
3. Check your Windows Tailscale IP:
   ```powershell
   tailscale ip -4
   ```
4. Build with Cargo:
   ```powershell
   cargo build --release
   ```

---

### 3.3 Multi-Node Workstation Fleet Management

AgentDeck supports managing an entire fleet of development machines (e.g. MacBook Air, Linux Build Server, Windows Desktop) from a single phone app.

#### 1. Naming Your Nodes via Tailscale MagicDNS
In the [Tailscale Admin Console](https://login.tailscale.com/admin/machines), assign friendly names to your machines:
- `macbook-pro` $\rightarrow$ `macbook-pro.your-tailnet.ts.net`
- `dev-linux` $\rightarrow$ `dev-linux.your-tailnet.ts.net`
- `win-workstation` $\rightarrow$ `win-workstation.your-tailnet.ts.net`

#### 2. Switching Nodes in AgentDeck Mobile
1. Open the **AgentDeck Mobile App**.
2. In the top app bar, tap the **Workstation Fleet Selector** icon (`💻 ▾`).
3. View all discovered machines with live status indicators (`● ONLINE` / `○ OFFLINE`), CPU load, and memory usage.
4. Tap any node to instantly switch your active control plane, interactive PTY terminal, live screen stream, and file explorer.

---

### 3.4 Firewall & Port Binding Rules (Port 8765)

The `agentdeckd` daemon listens on port `8765` by default (`AGENTDECK_PORT=8765`).

| Service | Port | Protocol | Binding Interface |
|---|---|---|---|
| HTTP REST API | `8765` | TCP | `0.0.0.0` (Tailscale mesh & localhost) |
| WebSockets (`/ws/events`, `/ws/terminal`) | `8765` | WS / WSS | `0.0.0.0` |
| Native Screen Live Stream | `8765` | HTTP / H.264 | `0.0.0.0` |
| Ollama Local LLM (Internal) | `11434` | HTTP | `127.0.0.1` (Localhost only) |

> [!IMPORTANT]
> Because `agentdeckd` binds to `0.0.0.0:8765`, it is accessible to any device on your private Tailscale network. It is **never** exposed to the public internet because your router does not forward port 8765.

---

### 3.5 MagicDNS & Auto-Discovery

If MagicDNS is enabled in your Tailnet:
1. You can connect to your host by its hostname instead of IP:
   ```
   http://macbook-air.your-tailnet.ts.net:8765
   ```
2. AgentDeck mobile auto-pings and resolves MagicDNS hosts on startup.

---

### 3.6 USB Debugging Fallback Proxy

If you are developing without a Tailscale network (or traveling offline), you can connect via USB cable:
```bash
# Forward phone port 8765 to laptop port 8765
adb reverse tcp:8765 tcp:8765
```
In the AgentDeck mobile app, set the host to `127.0.0.1:8765`.

---

## 4. Mobile Client Setup (`agentdeck_mobile`)

The mobile client is built using Flutter and connects to host workstations over Tailscale or local network.

### Compiling and Running
```bash
cd agentdeck_mobile
flutter pub get

# Run on connected Android / iOS device
flutter run
```

### Production Build
```bash
# Build Android APK
flutter build apk --release

# Build iOS App Archive (macOS only)
flutter build ipa --release
```

---

## 5. Supported AI Coding Agents & Engines

### 1. Google Antigravity (`agy` / Antigravity IDE Engine) — First-Class
- Autonomous vibecoding loop with multi-file code synthesis (`index.html`, `style.css`, `app.js`).
- Live ANSI terminal box frames and token streaming.
- Google OAuth account switcher and live token quota monitor.
- Usage:
  ```bash
  agy "create a folder in Documents named portfolio and build a dark theme website"
  ```

### 2. Anthropic Claude Code (`claude`)
- Automatically detected if `claude` is installed via npm (`npm i -g @anthropic-ai/claude-code`).
- Streams `<thinking>` reasoning XML blocks to mobile.

### 3. Google Gemini CLI (`gemini`)
- Structured function calling and repository indexing via Gemini 3.7 / 3.1 Pro.

### 4. Ollama Local Open-Weight Fleet
- Fully offline local execution with `qwen2.5-coder:7b`, `deepseek-r1`, or `llama3.3`.
- Configure via `OLLAMA_ENDPOINT` in `.env`.

---

## 6. Environment Variables Reference

Create a `.env` file in the root directory or configure system environment variables:

| Variable | Default Value | Description |
|---|---|---|
| `AGENTDECK_HOST` | `0.0.0.0` | IP interface to bind the daemon server to |
| `AGENTDECK_PORT` | `8765` | Daemon HTTP & WebSocket port |
| `GOOGLE_ACCOUNT_EMAIL` | Auto-detected | Active Google account for Antigravity quotas |
| `TAILSCALE_HOST_IP` | Auto-detected | Workstation's Tailscale IPv4 address |
| `OLLAMA_ENDPOINT` | `http://127.0.0.1:11434/api/generate` | Local Ollama REST endpoint |
| `AGENTDECK_LOCAL_MODEL` | `qwen2.5-coder:7b` | Default local reasoning model for `agy` |
| `RUST_LOG` | `info` | Rust logging filter (`trace`, `debug`, `info`, `warn`, `error`) |

---

## 7. Running in the Background as a 24/7 Service

### macOS (`launchd`)
AgentDeck includes a pre-configured `launchd` plist file in `scripts/com.agentdeck.daemon.plist`.

```bash
# 1. Build and copy the binary
cargo build --release
mkdir -p ~/.local/bin
cp target/release/agentdeckd ~/.local/bin/

# 2. Register the service with launchd
cp scripts/com.agentdeck.daemon.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentdeck.daemon.plist
```

To stop or inspect the daemon:
```bash
# Check status
launchctl list | grep agentdeck

# Stop daemon
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.agentdeck.daemon.plist
```

### Linux (`systemd`)
Create a user service at `~/.config/systemd/user/agentdeck.service`:
```ini
[Unit]
Description=AgentDeck Control Plane Daemon
After=network.target

[Service]
ExecStart=%h/.local/bin/agentdeckd
Restart=always
RestartSec=5
Environment=RUST_LOG=info

[Install]
WantedBy=default.target
```
Enable and start the service:
```bash
systemctl --user daemon-reload
systemctl --user enable --now agentdeck
```

---

## 8. Troubleshooting & FAQs

### 1. The mobile app shows "Disconnected" or cannot reach host
- Check that `agentdeckd` is running: `curl http://localhost:8765/health`
- If using USB debugging, verify port forwarding: `adb reverse tcp:8765 tcp:8765`
- If using Tailscale, verify both devices are on the same Tailnet: `tailscale ping 100.x.y.z`

### 2. Antigravity Quota is not updating
- The quota monitor reads your active Antigravity session transcript in `~/.gemini/antigravity-ide/brain/`.
- Ensure your Google account is configured in `~/.gemini/google_accounts.json` or `.env`.

### 3. Screen Live View permissions on macOS
- macOS requires Screen Recording permission for capturing the display.
- Go to **System Settings > Privacy & Security > Screen Recording** and grant permission to `agentdeckd` or your terminal app.

---

## 📄 License & Contributing

AgentDeck is open-source software licensed under the [MIT License](LICENSE). Pull requests, issues, and feature suggestions are welcome!
