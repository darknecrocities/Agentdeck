# Agent Integration & Control Plane Specification

AgentDeck provides a local-first, unified AI engineering control plane for autonomous coding agents. It orchestrates background agent processes, captures real-time Chain of Thought (CoT) reasoning, routes Model Context Protocol (MCP) tool calls, enforces security approval gates, and streams live IDE chat and telemetry over an encrypted Tailscale WireGuard mesh.

---

## 1. Unified Architecture & Adapter Abstraction

All agent integrations implement the standard `AgentAdapter` trait in Rust (`src/agents/trait.rs`), which decouples process lifecycle, structured stream parsing, and capability negotiation from the transport layer.

```
┌──────────────────────────────────────────────────────────────────┐
│                      AgentDeck Mobile Client                     │
│    (Live Chat, CoT Stream, Tool Diffs, Approvals, Remote Host)   │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Tailscale Mesh (100.x.y.z:8765)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                      agentdeckd Daemon Engine                    │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ AgentManager (Process Lifetime, Stdin/Stdout, Crash Recovery)│ │
│ └───────────────────────────────┬──────────────────────────────┘ │
│                                 │
│      ┌──────────────────────────┼──────────────────────────┐     │
│      ▼                          ▼                          ▼     │
│ ┌───────────────┐        ┌───────────────┐        ┌────────────┐ │
│ │ Antigravity   │        │ Claude Code   │        │ Gemini CLI │ │
│ │ Adapter (agy) │        │ Adapter       │        │ & Ollama   │ │
│ └───────┬───────┘        └───────┬───────┘        └─────┬──────┘ │
│         │                        │                      │        │
│         ▼                        ▼                      ▼        │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Model Context Protocol (MCP) & Built-in Tool Dispatch Bridge │ │
│ │ (File Edits, Shell Exec, Browser Automation, Search, Git)    │ │
│ └───────────────────────────────┬──────────────────────────────┘ │
│                                 │
│ ┌───────────────────────────────┴──────────────────────────────┐ │
│ │ Security & Approvals Engine (Interactive Push Auth Gates)    │ │
│ └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Core Responsibilities of an `AgentAdapter`
1. **Lifecycle Management**: Spawn, supervise, keep-alive, pause, resume, and terminate agent subprocesses across host OS environments (macOS, Linux, Windows).
2. **Chain of Thought (CoT) Interception**: Stream continuous model reasoning, planning milestones, and subagent delegation directly to mobile clients before actions execute.
3. **MCP Tool Routing & Diff Generation**: Parse and execute Model Context Protocol (MCP) and native tool requests, capturing file diffs (`+` / `-`), command outputs, and exit codes.
4. **Approval Gate Integration**: Intercept destructive or sensitive tool actions (e.g. `rm -rf`, force push, credential access) and hold execution until user approves via mobile push.
5. **State & Conversation Continuity**: Support conversational resumption (`--continue` or session ID references) across disconnections and reboots.

---

## 2. Supported AI Coding Agents

### 1. Google Antigravity (`agy` / Antigravity IDE Engine) — First-Class Priority Integration

Google Antigravity is the primary autonomous software engineering agent supported by AgentDeck.

- **CLI Binary**: `agy` (Discovered via `PATH` or `~/.gemini/antigravity/bin/agy`)
- **Execution Mode**: Structured JSON streaming (`--output-format stream-json`)
- **Continuation Flag**: `agy --continue` or `agy --conversation <id>`
- **Live IDE Brain Path**: `~/.gemini/antigravity-ide/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`

#### Antigravity Chain of Thought & Reasoning
- Emits real-time `THINKING` steps containing model analysis, problem decomposition, and execution planning.
- Mobile client displays an animated reasoning indicator with collapsible markdown thoughts and stage checkpoints.
- Supports reasoning effort configuration (`low`, `medium`, `high`).

#### Remote Antigravity Auth & Account Switching
- Reads and updates active Google OAuth profiles in `~/.gemini/google_accounts.json` and `~/.gemini/oauth_creds.json`.
- Mobile users can switch between stored Google accounts with 1-tap, link new accounts, test auth status, and inspect remaining Gemini / Claude token quotas in real time.

#### Antigravity Tool Protocol & File Edit Streaming
AgentDeck maps all Antigravity tool invocations into structured mobile widgets:
- `replace_file_content` / `multi_replace_file_content`: Generates line-by-line syntax-highlighted diffs (`+` added, `-` removed) with target file path and line numbers.
- `write_to_file`: Captures complete file creation events with file size and directory path.
- `run_command`: Executes terminal commands in persistent PTY shells with working directory and exit code tracking (`EXIT 0` / `EXIT CODE`).
- `view_file` / `list_dir` / `grep_search`: Inspects local filesystem state with sandbox traversal guards.
- `generate_image`: Renders UI mockups and design assets natively in chat.
- `browser_subagent`: Controls headless browser sessions for web testing and DOM inspection.
- `ask_question`: Presents interactive multiple-choice and write-in forms to the user.

---

### 2. Anthropic Claude Code (`claude`)

- **CLI Binary**: `claude`
- **Execution Mode**: Non-interactive stream / print mode (`claude --print`)
- **Reasoning**: Extracts `<thinking>` XML blocks and converts them into structured `ThinkingUpdate` events.
- **MCP Integration**: Compatible with standard Claude Code MCP server configurations defined in `~/.claude.json`.
- **Tool Protocol**:
  - `Bash`: Shell execution routed through AgentDeck approval filters.
  - `FileEdit` / `FileWrite`: Converted into unified AgentDeck file modification events.
  - `GlobTool` / `GrepTool`: Workspace search and file pattern matching.

---

### 3. Google Gemini CLI (`gemini`)

- **CLI Binary**: `gemini`
- **Execution Mode**: Headless CLI prompt execution with JSON function calling.
- **Auth**: Managed via Gemini API keys or Google Cloud Vertex AI credentials.
- **Capabilities**: High-throughput analysis, long-context repository indexing, and multi-file code refactoring.

---

### 4. Ollama Local Open-Weight Fleet (`ollama`)

- **Daemon Endpoint**: `http://127.0.0.1:11434` (Ollama REST API)
- **Supported Models**: `deepseek-r1:latest`, `qwen2.5-coder:32b`, `codellama:70b`, `llama3.3:70b`
- **Offline Mode**: 100% local execution without external cloud connectivity.
- **Reasoning Stream**: Native parsing of `<think>...</think>` tokens for reasoning models (DeepSeek-R1).

---

## 3. Model Context Protocol (MCP) Integration

AgentDeck acts as both an **MCP Host** and an **MCP Client Bridge**, allowing mobile devices to expose and consume tools dynamically.

```
┌─────────────────────────────────────────────────────────────┐
│                      AgentDeck Daemon                       │
│ ┌───────────────────────┐         ┌───────────────────────┐ │
│ │ Built-in Tool Server  │         │ External MCP Servers  │ │
│ │ • Filesystem Watcher  │         │ • Git / GitHub API    │ │
│ │ • Terminal PTY Pipe   │         │ • Database Tools      │ │
│ │ • Screen / Cam Stream │         │ • Custom MCP Sidecars │ │
│ └───────────┬───────────┘         └───────────┬───────────┘ │
│             │                                 │             │
│             └────────────────┬────────────────┘             │
│                              ▼                              │
│                Unified MCP Tool Registry                    │
│                              │                              │
│       ┌──────────────────────┼──────────────────────┐       │
│       ▼                      ▼                      ▼       │
│ Antigravity (agy)       Claude Code            Gemini CLI   │
└─────────────────────────────────────────────────────────────┘
```

### Standard Tool Registry Schemas

#### 1. File Modification Tool (`replace_file_content`)
```json
{
  "name": "replace_file_content",
  "category": "FILE_EDIT",
  "parameters": {
    "TargetFile": "/Users/arronkianparejas/agentdeck/lib/main.dart",
    "StartLine": 45,
    "EndLine": 60,
    "TargetContent": "...",
    "ReplacementContent": "...",
    "Instruction": "Add live Tailscale status indicator"
  }
}
```

#### 2. Shell Execution Tool (`run_command`)
```json
{
  "name": "run_command",
  "category": "COMMAND",
  "parameters": {
    "CommandLine": "flutter test",
    "Cwd": "/Users/arronkianparejas/agentdeck/agentdeck_mobile",
    "WaitMsBeforeAsync": 10000
  }
}
```

#### 3. Browser Subagent Tool (`browser_subagent`)
```json
{
  "name": "browser_subagent",
  "category": "BROWSER",
  "parameters": {
    "TaskName": "Verify Login Flow",
    "Task": "Navigate to http://localhost:3000 and verify login redirects to dashboard",
    "RecordingName": "login_test"
  }
}
```

---

## 4. Security, Access Controls & Approval Gates

AgentDeck enforces strict security boundaries between the mobile control plane and host machine.

### Privilege Levels
1. **Read-Only**: File inspection, git log reading, screen viewing, and log tailing.
2. **Workspace-Only**: Modifications strictly confined to configured project roots (path traversal blocked by canonical path checks).
3. **Full System**: Command execution and system file browsing across host permissions.
4. **Strict Approval (Default)**: Dangerous commands and destructive actions require explicit mobile authorization.

### Actions Requiring Approval
- Destructive file removals (`rm -rf`, `git reset --hard`)
- Remote shell execution containing root/sudo privileges
- Git force pushes (`git push --force`)
- Modifications to environment secret files (`.env`, `.gemini/oauth_creds.json`, SSH keys)

### Interactive Approval Workflow
1. Agent emits `ApprovalRequired` event with action type, command/diff preview, and risk rating.
2. Daemon suspends agent process and pushes notification to connected mobile devices.
3. Mobile user reviews diff and taps **APPROVE** (`/api/approvals/:id/approve`) or **DENY** (`/api/approvals/:id/deny`).
4. Daemon sends response to agent stdin to resume execution safely.

---

## 5. Remote Host Telemetry & Machine Access

AgentDeck connects mobile devices to host workstations via Tailscale WireGuard mesh with zero open public ports:

- **Host Metrics**: Real-time CPU usage, Memory (RAM) percentage, and available Disk GB.
- **Remote Machine Tools**:
  - **Screen Live View**: Low-latency H.264 / MJPEG live desktop screen streaming.
  - **Webcam Stream**: Live video feed from workstation webcam for remote workstation monitoring.
  - **Remote App Launcher**: 1-tap launching of VS Code, Terminal, Antigravity IDE, Chrome, and Cursor.
  - **File Browser & Uploader**: Upload media, files, and assets from mobile directly into workspace folders.
  - **Multi-Workstation Fleet Switcher**: Seamless switching between Mac, Windows, and Linux workstation nodes.

---

## 6. Event Schema Reference

All agent events transmitted across WebSockets (`/ws/sessions/:id` and `/ws/events`) follow the standard schema:

```json
{
  "event_id": 1042,
  "session_id": "sess_8f91a0c2",
  "agent": "antigravity",
  "project_id": "proj_agentdeck_01",
  "timestamp": "2026-08-30T17:34:00Z",
  "type": "ToolFinished",
  "data": {
    "tool": "replace_file_content",
    "file_path": "/Users/arronkianparejas/agentdeck/lib/screens/dashboard_screen.dart",
    "category": "FILE_EDIT",
    "instruction": "Integrate Tailscale radar pulse and mascot animations",
    "status": "SUCCESS",
    "diff_snippet": "+ TailscaleRadarPulse(latencyMs: 12)"
  }
}
```

### Event Types Catalog
| Event Type | Source | Description |
|---|---|---|
| `SessionStarted` | Daemon | Subprocess initialized with project context and model configuration |
| `ThinkingStarted` | Agent | Chain of thought reasoning begins |
| `ThinkingUpdate` | Agent | Incremental thinking milestone, reasoning token, or subagent plan |
| `AgentMessage` | Agent | Generated user-facing response / assistant markdown text |
| `ToolStarted` | Agent | MCP or built-in tool execution dispatched |
| `ToolFinished` | Agent | Tool execution result, diff summary, or command output captured |
| `FileCreated` | Agent | New file written to workspace filesystem |
| `FileModified` | Agent | Existing file edited with line range and diff |
| `CommandStarted` | Agent | Shell command spawned in PTY environment |
| `CommandFinished` | Agent | Shell command exited with status code and stdout/stderr |
| `ApprovalRequired` | Security | Action suspended pending mobile approval |
| `SessionCompleted` | Daemon | Task finished successfully and agent exited cleanly |
| `SessionFailed` | Daemon | Agent process crashed or execution aborted |
