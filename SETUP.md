# 🚀 AgentDeck: Open-Source Setup & Deployment Guide

AgentDeck is a local-first, unified AI engineering control plane for autonomous coding agents (Google Antigravity, Claude Code, Gemini CLI, and Ollama). It allows you to monitor, prompt, and control AI coding agents running on your workstation from your mobile phone over an encrypted Tailscale WireGuard mesh with zero public open ports.

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Quickstart in 5 Minutes](#2-quickstart-in-5-minutes)
3. [Workstation Daemon Setup (`agentdeckd`)](#3-workstation-daemon-setup-agentdeckd)
4. [Mobile Client Setup (`agentdeck_mobile`)](#4-mobile-client-setup-agentdeck_mobile)
5. [Tailscale WireGuard Mesh Configuration](#5-tailscale-wireguard-mesh-configuration)
6. [Supported AI Coding Agents & Engines](#6-supported-ai-coding-agents--engines)
7. [Environment Variables Reference](#7-environment-variables-reference)
8. [Running in the Background as a 24/7 Service (macOS/Linux)](#8-running-in-the-background-as-a-247-service-macoslinux)
9. [Troubleshooting & FAQs](#9-troubleshooting--faqs)

---

## 1. Prerequisites

Before installing AgentDeck, make sure your machine meets the following requirements:

### Workstation Host (macOS / Linux / Windows WSL2)
- **Rust toolchain 1.80+**:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```
- **SQLite 3**: (pre-installed on macOS/Linux; required for local event storage).
- **Tailscale**: (free for personal use, provides peer-to-peer encrypted WireGuard mesh).
  - macOS: `brew install --cask tailscale` or download from [tailscale.com](https://tailscale.com).
  - Linux: `curl -fsSL https://tailscale.com/install.sh | sh`
- **Optional Local LLM Engine (Ollama)**:
  ```bash
  brew install ollama
  ollama run qwen2.5-coder:7b
  ```

### Mobile Development (Android / iOS)
- **Flutter SDK 3.24+**:
  ```bash
  # Check Flutter setup
  flutter doctor
  ```
- **Android Studio / Xcode**: For compiling Android APK or iOS binary.
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
Edit `.env` to customize your port, Google account email, or Tailscale IP if desired.

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

## 3. Workstation Daemon Setup (`agentdeckd`)

The `agentdeckd` daemon manages agent processes, terminal PTY multiplexing, live filesystem watchers, and WebSockets.

### Building for Production
```bash
cargo build --release --bin agentdeckd
```
The optimized binary will be located at `target/release/agentdeckd`.

### Installing the CLI Tools
To install `agentdeckd` and the Antigravity `agy` autonomous coding CLI to your PATH:
```bash
mkdir -p ~/.local/bin
cp target/release/agentdeckd ~/.local/bin/
cp scripts/agy ~/.local/bin/agy
chmod +x ~/.local/bin/agy
ln -sf ~/.local/bin/agy ~/.local/bin/aagy
```
Ensure `~/.local/bin` is in your shell PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc # or ~/.bashrc
source ~/.zshrc
```

---

## 4. Mobile Client Setup (`agentdeck_mobile`)

The mobile client is built using Flutter and connects to the host machine over Tailscale or local network.

### Testing via USB Debugging (Instant Local Testing)
If your phone is plugged in via USB:
```bash
adb reverse tcp:8765 tcp:8765
cd agentdeck_mobile
flutter run -d <your-device-id>
```

### Testing over WiFi / Tailscale Mesh
1. Open the Tailscale app on your phone and log in.
2. Note your host workstation's Tailscale IP (`tailscale ip -4` on host, e.g. `100.x.y.z`).
3. In `AgentDeck` mobile, tap the **Tailscale Mesh** banner at the top and set the host to `100.x.y.z:8765`.

---

## 5. Tailscale WireGuard Mesh Configuration

Tailscale allows secure mobile-to-laptop connectivity anywhere in the world without exposing public ports, configuring router port forwarding, or paying for cloud servers.

```
┌────────────────────────┐                   ┌────────────────────────┐
│  Mobile Phone Client   │                   │  MacBook Host Daemon   │
│ (Tailscale: 100.x.y.1) │ <───────────────> │ (Tailscale: 100.x.y.2) │
└────────────────────────┘  WireGuard Mesh   └────────────────────────┘
                              (Port 8765)
```

### Steps to Connect:
1. Install Tailscale on your host machine:
   ```bash
   tailscale up
   ```
2. Check your host Tailscale IPv4 address:
   ```bash
   tailscale ip -4
   ```
3. Install Tailscale on your mobile phone from the App Store / Play Store and log into the **same** Google/GitHub account.
4. Launch the `AgentDeck` mobile app. It will automatically detect your Tailscale connection and connect to `ws://100.x.y.2:8765`.

---

## 6. Supported AI Coding Agents & Engines

AgentDeck comes with built-in adapters for four major AI agent architectures:

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

## 7. Environment Variables Reference

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

## 8. Running in the Background as a 24/7 Service (macOS/Linux)

### macOS (`launchd`)
AgentDeck includes a pre-configured `launchd` plist file in `scripts/com.agentdeck.daemon.plist`.

To install and start the background daemon:
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

## 9. Troubleshooting & FAQs

### 1. The mobile app shows "Disconnected" or cannot reach host
- Check that `agentdeckd` is running (`cargo run --bin agentdeckd` or `curl http://localhost:8765/api/health`).
- If using USB debugging, run `adb reverse tcp:8765 tcp:8765`.
- If using Tailscale, ensure both devices are active on the same Tailnet and verify with `ping 100.x.y.z` from your phone or laptop.

### 2. Antigravity Quota is not updating
- The quota monitor reads your active Antigravity session transcript in `~/.gemini/antigravity-ide/brain/`.
- Ensure your Google account is configured in `~/.gemini/google_accounts.json` or `.env`.

### 3. Screen Live View permissions on macOS
- macOS requires Screen Recording permission for capturing the display.
- Go to **System Settings > Privacy & Security > Screen Recording** and grant permission to `agentdeckd` or your terminal app.

---

## 📄 License & Contributing

AgentDeck is open-source software licensed under the [MIT License](LICENSE). Pull requests, issues, and feature suggestions are welcome!
