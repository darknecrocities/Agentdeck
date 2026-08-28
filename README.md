# AgentDeck

**AgentDeck** is a local-first remote AI engineering control plane. It allows you to run autonomous AI coding agents (such as Google Antigravity CLI `agy`, Claude Code, Gemini CLI, and Ollama) persistently on your local computer (e.g. Mac) and monitor, control, prompt, and audit them remotely from your phone over Tailscale.

---

## Key Features

- **Native Antigravity CLI Integration**: Full structured streaming JSON parser for `agy`, supporting conversation continuations, subagent monitoring, and tool inspection without GUI scraping.
- **Persistent Local Daemon (`agentdeckd`)**: The daemon manages agent lifecycles independently of client connectivity. Disconnecting the mobile app never kills running jobs.
- **Offline State Reconstruction & Replay**: Sequential event logs in SQLite allow the mobile client to seamlessly reconstruct what happened while away.
- **Interactive PTY Terminal**: Full terminal emulation over WebSockets with mobile touch controls.
- **Filesystem & Git Monitoring**: Real-time project file watching, debounced diffs, and GitHub PR/issue tracking.
- **Security & Approvals**: High-risk actions (force pushes, deletions) are held in an approval queue before execution.
- **Tailscale First**: Designed to operate inside your private encrypted Tailscale network with zero public internet exposure.
- **Cyberpunk / Terminal Black UX**: Flutter mobile client styled with sleek dark terminal aesthetics, glowing indicators, and live animated feeds.

---

## Quick Start

### 1. Build and Run Daemon
```bash
cargo build --release
./target/release/agentdeckd --config agentdeck.toml
```

### 2. Check System Diagnostics
```bash
./target/release/agentdeck doctor
```

### 3. Run Flutter Mobile Client
```bash
cd agentdeck_mobile
flutter run
```
