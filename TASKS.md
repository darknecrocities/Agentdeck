# AgentDeck Task List & Implementation Progress

## Phase 0: Architecture & Setup
- [x] Inspect environment (macOS ARM64, Rust 1.98, Flutter 3.41, Node, Gh, Claude, Gemini, Ollama)
- [x] Create core architectural design document (`ARCHITECTURE.md`)
- [x] Create security specification (`SECURITY.md`)
- [x] Create task roadmap (`TASKS.md`)
- [x] Create developer documentation (`DEVELOPMENT.md`, `API.md`, `AGENTS.md`, `README.md`)

## Phase 1: Rust Daemon Core (`agentdeckd`)
- [ ] Create Cargo workspace / project structure with required dependencies (`tokio`, `axum`, `sqlx`, `serde`, `portable-pty`, `notify`, `tracing`, `clap`, `uuid`, etc.)
- [ ] Implement TOML configuration loader (`agentdeck.toml`)
- [ ] Implement SQLite schema and migration system
- [ ] Implement Axum REST server with `/health`, `/api/device`, `/api/status`
- [ ] Implement structured tracing and logging

## Phase 2: Antigravity CLI Adapter (`agy`)
- [ ] Implement `src/agents/antigravity/` adapter
- [ ] CLI executable detection & version resolution
- [ ] Process launcher supporting `--output-format stream-json`, `--continue`, and `--conversation <id>`
- [ ] Streaming JSON parser for structured events (`AgentMessage`, `ToolStarted`, `ToolFinished`, `FileModified`, `CommandStarted`, etc.)
- [ ] Session persistence & continuation mapping
- [ ] Mock agent test fixture (`tests/fixtures/fake-agent`)

## Phase 3: Event Bus & SQLite Persistence
- [ ] Central `EventBus` with monotonically increasing sequence IDs (`event_id`)
- [ ] SQLite event logging
- [ ] Offline reconnection replay (`GET /api/sessions/:id/events?after=X`)
- [ ] WebSocket event streaming endpoints (`/ws/events`, `/ws/sessions/:id`)

## Phase 4: Filesystem & Git Subsystems
- [ ] Project filesystem monitoring with `notify` and event debouncing/coalescing
- [ ] Path traversal protection for all filesystem APIs
- [ ] Git repository inspection (branch, dirty status, diffs, log, commit, push)
- [ ] GitHub CLI integration (`gh pr list`, `gh issue list`, `gh run list`)

## Phase 5: Terminal / PTY Subsystem
- [ ] Real PTY session manager via `portable-pty`
- [ ] Persistent shell processes (zsh/bash)
- [ ] Bidirectional WebSocket terminal streaming (`/ws/terminal/:id`)
- [ ] Terminal resize and input endpoints

## Phase 6: Approvals & Security
- [ ] Risk classification engine (Low, Medium, High, Critical)
- [ ] Approval request queue and persistence
- [ ] Approve / Deny endpoints and audit trail

## Phase 7: Multi-Agent Adapters
- [ ] Claude Code adapter
- [ ] Gemini CLI adapter
- [ ] Ollama adapter

## Phase 8: AgentDeck CLI (`agentdeck`)
- [ ] CLI subcommands (`status`, `projects`, `agents`, `start`, `stop`, `logs`, `doctor`, `config`)
- [ ] Comprehensive `agentdeck doctor` diagnostic tool

## Phase 9: Flutter Mobile Control Center (`agentdeck_mobile`)
- [ ] Flutter project setup with Terminal Black theme & responsive layout
- [ ] Dashboard screen (Hardware stats, Agents, Projects, Approvals)
- [ ] Agent Session screen (Task progress, plan checklist, activity feed, prompt input)
- [ ] Real-time Timeline screen (Chronological event stream with offline replay)
- [ ] Interactive ANSI Terminal screen with touch modifier keys
- [ ] Files & Diff viewer screen
- [ ] Git & GitHub management screen
- [ ] Approvals action screen
- [ ] Settings & Tailscale connectivity screen

## Phase 10: Verification & Testing
- [ ] End-to-end integration tests (Rust daemon + fake-agent + replay + PTY)
- [ ] Flutter tests and build validation
