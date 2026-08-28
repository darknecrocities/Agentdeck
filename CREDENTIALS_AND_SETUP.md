# AgentDeck: Credentials & Remote Online Monitoring Setup

This guide explains all credentials, API keys, and automated setup required to monitor and control your Mac from your phone from anywhere in the world.

---

## 1. Credentials & API Keys Breakdown

| Component / Agent | What You Need | Where To Get It | Is It Required? | Current Status on Your Mac |
| :--- | :--- | :--- | :--- | :--- |
| **Tailscale** *(Remote Online Access)* | Free Tailscale account | [tailscale.com](https://tailscale.com) (Log in with Google/Apple/GitHub) | **Required for Remote Access** *(or local Wi-Fi)* | Ready to connect |
| **AgentDeck Daemon Token** | `AGENTDECK_AUTH_TOKEN` in `.env` | Auto-generated in your `.env` | **Required** for pairing phone | Generated & Configured |
| **GitHub CLI** | `gh` / Personal Access Token | Run `gh auth login` | **Optional** for GitHub PRs/Issues | **Already Logged In** (`darknecrocities`) |
| **Antigravity CLI** | Google Account / `agy` auth | Google Antigravity | **Priority Agent** | Integrated via `agy` / Headless |
| **Gemini CLI** | `GEMINI_API_KEY` | [aistudio.google.com](https://aistudio.google.com) *(Free Tier available)* | **Optional** for Gemini CLI agent | CLI Installed (`0.43.0`) |
| **Claude Code** | `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) | **Optional** for Claude Code agent | CLI Installed (`2.1.158`) |
| **Ollama** | No API Key needed *(100% Local & Free)* | Runs locally via `ollama run <model>` | **Optional** for Local LLMs | CLI Installed (`0.32.0`) |

---

## 2. How Remote Online Monitoring Works (No Port Forwarding Needed)

AgentDeck uses **Tailscale** (encrypted WireGuard mesh network):
1. **On your Mac**: Install Tailscale (`brew install tailscale` or Mac App Store) and sign in. Your Mac gets a private static IP (e.g. `100.85.120.45`).
2. **On your Phone**: Install the Tailscale app (iOS / Android) and sign into the **same** Tailscale account.
3. **On your Phone in AgentDeck**: Open Settings and set Daemon Endpoint to:
   ```
   http://100.85.120.45:8765
   ```
4. **Done!** You can now leave your Mac at home on Wi-Fi, walk outside on 5G mobile data, and monitor/control all coding agents in real-time.

---

## 3. Automated 24/7 Background Service (`launchd`)

To have the AgentDeck daemon start automatically on Mac boot and keep running 24/7 without keeping any terminal window open:

```bash
# Run the automated installer
./scripts/setup-all.sh
```

This:
- Compiles the optimized release binaries
- Configures your `.env` with security tokens
- Installs the `launchd` background daemon at `~/Library/LaunchAgents/com.agentdeck.daemon.plist`
- Starts `agentdeckd` in the background with auto-restart on crash

---

## 4. Setting Your Optional AI API Keys in `.env`

Edit `/Users/arronkianparejas/agentdeck/.env`:

```bash
# Gemini API Key (get from https://aistudio.google.com)
export GEMINI_API_KEY="AIzaSy..."

# Anthropic Claude API Key (get from https://console.anthropic.com)
export ANTHROPIC_API_KEY="sk-ant-..."
```

---

## 5. Running the Mobile App

### On your Phone:
1. Connect your phone via USB or build APK/iOS:
```bash
cd agentdeck_mobile
flutter run
```
2. Enter your Mac's Tailscale IP (`http://100.x.x.x:8765`) in Settings.
3. You now have full remote control over your Mac's AI coding workstation.
