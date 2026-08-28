# AgentDeck Architecture

AgentDeck is a local-first remote AI engineering control plane. It enables developers to monitor, control, prompt, and audit autonomous AI coding agents running on their local machines (macOS) from a mobile device (Flutter client) securely connected over Tailscale.

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile Client                    │
│            (Hacker/Terminal Black Theme UI)                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ Encrypted WireGuard Tunnel
                               │ (Tailscale / 100.x.x.x)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     agentdeckd (Daemon)                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Axum REST API (/api/...) & WebSocket Streams (/ws/..) │  │
│  └───────────────────────────┬───────────────────────────┘  │
│                              │                              │
│       ┌──────────────────────┼──────────────────────┐       │
│       ▼                      ▼                      ▼       │
│ ┌───────────┐          ┌───────────┐          ┌───────────┐ │
│ │ EventBus  │          │ SQLite DB │          │ Security  │ │
│ │ Monotonic │          │ State &   │          │ Approvals │ │
│ │ Sequences │          │ History   │          │ & Auth    │ │
│ └─────┬─────┘          └─────┬─────┘          └─────┬─────┘ │
│       │                      │                      │       │
│       ├──────────────────────┴──────────────────────┤       │
│       ▼                                             ▼       │
│ ┌───────────────────────┐                 ┌───────────────┐ │
│ │ AgentManager          │                 │ Portable-PTY  │ │
│ │ Process Lifecycle     │                 │ Shell Sessions│ │
│ └─────────┬─────────────┘                 └───────────────┘ │
│           │                                                 │
│     ┌─────┴───────────┬───────────────┬───────────────┐     │
│     ▼                 ▼               ▼               ▼     │
│ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───┐ │
│ │  Antigravity  │ │  Claude Code  │ │  Gemini CLI   │ │   │ │
│ │     (agy)     │ │   (claude)    │ │   (gemini)    │ │   │ │
│ └───────────────┘ └───────────────┘ └───────────────┘ └───┘ │
│                                                             │
│ ┌─────────────────────────┐     ┌─────────────────────────┐ │
│ │ Filesystem Watcher      │     │ Git & GitHub Manager    │ │
│ │ (Notify + Debouncing)   │     │ (Branch, Diff, PRs)     │ │
│ └─────────────────────────┘     └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Tenets

1. **Persistent Daemon Ownership**: The daemon (`agentdeckd`) owns all agent processes, terminal PTY instances, and file watchers. Client network disconnections NEVER terminate background jobs.
2. **First-Class Antigravity CLI Integration**: Interacts natively with `agy` using `--output-format stream-json`, `--continue`, and `--conversation <id>` to consume structured event streams without scraping TUI escape codes.
3. **Offline Reconnection & State Reconstruction**: Sequential `event_id` numbering in SQLite allows reconnecting clients to replay all missed events.
4. **Zero Cloud Dependencies**: Completely local-first and self-contained; remote connectivity is provided securely via Tailscale mesh VPN.
5. **Multi-Agent Extensibility**: Clean `AgentAdapter` trait standardizing process management, prompting, streaming, and capabilities across Antigravity, Claude Code, Gemini CLI, and Ollama.
6. **Safety & Approvals**: High-risk actions (force pushes, destructive deletions, arbitrary shell executions) require explicit user approval.
