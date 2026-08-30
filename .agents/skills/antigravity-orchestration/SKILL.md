---
name: antigravity-orchestration
description: Master guide for orchestrating Google Antigravity (agy) CLI, managing Chain of Thought (CoT) reasoning streams, switching Google OAuth accounts, quota tracking, and continuous conversational sessions. Activate when interacting with or configuring the Antigravity agent engine.
---

# Antigravity Orchestration & Vibe Engineering Skill

This skill provides step-by-step procedures, CLI flags, JSON stream handling, and best practices for controlling Google Antigravity (`agy`) from AgentDeck.

---

## 1. CLI Execution Modes

Antigravity supports structured streaming and conversational continuations:

```bash
# Launch interactive structured JSON stream with specific model and effort
agy --output-format stream-json --model gemini-3.7-flash --effort high "Analyze workspace architecture"

# Resume active conversation session
agy --continue "Proceed with the planned implementation"

# Resume specific conversation ID
agy --conversation sess_8f91a0c2 --continue "Run tests and verify fixes"
```

---

## 2. Chain of Thought (CoT) Reasoning Parsing

Antigravity emits real-time planning and reasoning steps:
- **`THINKING`**: Captured inside `PLANNER_RESPONSE` events.
- **Stage Extraction**: Parse problem decomposition, file inspection plans, and architectural decisions.
- **UI Stream**: Stream raw thought chunks to the mobile client before tool execution begins so the user sees live model reasoning in real-time.

```json
{
  "step_index": 3,
  "source": "MODEL",
  "type": "PLANNER_RESPONSE",
  "status": "DONE",
  "thinking": "Decomposing the task: 1) Verify WireGuard mesh status, 2) Edit dashboard telemetry...",
  "tool_calls": [...]
}
```

---

## 3. Remote Google OAuth Account Switching

Antigravity credentials reside in:
- `~/.gemini/google_accounts.json`: Contains `"active"` email and `"old"` previous accounts array.
- `~/.gemini/oauth_creds.json`: Stored OAuth tokens and refresh parameters.

### Account Switching Procedure
1. Inspect `~/.gemini/google_accounts.json`.
2. Move previous `active` to `old` list if not already present.
3. Set desired target email to `"active"`.
4. Trigger `/api/accounts/antigravity/switch` in AgentDeck daemon.
5. Invalidate cached token summary and fetch updated Gemini 5-Hour / Weekly quotas.

---

## 4. Tool Protocol Handling

When Antigravity requests tool execution:
- **File Modifications** (`replace_file_content`, `multi_replace_file_content`): Compute exact syntax-highlighted diffs (`+` / `-`).
- **File Writes** (`write_to_file`): Validate target directory exists and verify written byte count.
- **Shell Commands** (`run_command`): Route through PTY shell with exit code capture.
- **Approvals** (`ask_question` / dangerous actions): Suspend execution and dispatch push authorization gate.
