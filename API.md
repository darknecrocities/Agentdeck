# AgentDeck REST & WebSocket API Specification

## Authentication
Pass `Authorization: Bearer <token>` in headers for REST, or `?token=<token>` for WebSockets.

---

## REST Endpoints

### System & Health
- `GET /health`: Health status probe `{"status": "ok", "version": "0.1.0"}`
- `GET /api/device`: Machine telemetry (OS, CPU, memory, disk, uptime, Tailscale IP)
- `GET /api/diagnostics`: Doctor diagnostics report (CLI tools, databases, services)

### Projects
- `GET /api/projects`: List registered projects
- `POST /api/projects`: Register a new project `{ "name": "...", "path": "...", "default_agent": "antigravity" }`
- `DELETE /api/projects/:id`: Unregister project
- `GET /api/projects/:id/files?path=...`: Browse project directory tree
- `GET /api/projects/:id/files/content?path=...`: Read file content
- `GET /api/projects/:id/git/status`: Git repository state (branch, dirty, modified)
- `GET /api/projects/:id/git/diff`: Unified git diff
- `GET /api/projects/:id/git/log`: Recent commit history
- `POST /api/projects/:id/git/commit`: Create commit `{ "message": "..." }`
- `POST /api/projects/:id/git/push`: Push to remote
- `POST /api/projects/:id/git/pull`: Pull from remote
- `GET /api/projects/:id/github`: GitHub PRs, issues, actions

### Agents & Sessions
- `GET /api/agents`: List all agent adapters (Antigravity, Claude, Gemini, Ollama) and status
- `GET /api/agents/:id`: Detailed agent info & capabilities
- `GET /api/sessions`: List active and historical agent sessions
- `POST /api/sessions`: Start new session `{ "project_id": "...", "agent": "antigravity", "prompt": "..." }`
- `GET /api/sessions/:id`: Get session details
- `POST /api/sessions/:id/prompt`: Send follow-up prompt to running session `{ "prompt": "..." }`
- `POST /api/sessions/:id/continue`: Resume previous conversation
- `POST /api/sessions/:id/stop`: Gracefully stop agent
- `POST /api/sessions/:id/kill`: Force kill agent process
- `GET /api/sessions/:id/events?after_event_id=0`: Fetch event stream with replay

### Terminal / PTY
- `GET /api/terminal/sessions`: List active PTY shell sessions
- `POST /api/terminal/session`: Spawn a new PTY session `{ "project_id": "...", "cols": 80, "rows": 24 }`
- `POST /api/terminal/:id/input`: Write input bytes to shell
- `POST /api/terminal/:id/resize`: Resize PTY `{ "cols": 100, "rows": 30 }`
- `DELETE /api/terminal/:id`: Terminate terminal session

### Approvals
- `GET /api/approvals`: List pending approvals
- `POST /api/approvals/:id/approve`: Approve pending action
- `POST /api/approvals/:id/deny`: Deny pending action

---

## WebSocket Endpoints

- `WS /ws/events?after_event_id=...`: Live stream of all AgentDeck system, agent, and file events
- `WS /ws/sessions/:id`: Live stream dedicated to an agent session
- `WS /ws/terminal/:id`: Bidirectional binary/text PTY terminal stream
