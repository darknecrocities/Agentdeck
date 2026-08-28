# Agent Integration Guide

AgentDeck supports multiple AI coding agents via a unified `AgentAdapter` abstraction.

## Supported Adapters

### 1. Antigravity CLI (`agy`) — Priority First-Class Integration
- **Executable**: `agy`
- **Output Format**: `--output-format stream-json`
- **Continuation**: `--continue` or `--conversation <id>`
- **Structured Events Handled**:
  - `SessionStarted`, `SessionResumed`
  - `AgentMessage`
  - `ThinkingStarted`, `ThinkingUpdate` (abstracted away from hidden chain-of-thought)
  - `ToolStarted`, `ToolFinished`
  - `FileCreated`, `FileModified`, `FileDeleted`
  - `CommandStarted`, `CommandFinished`
  - `ApprovalRequired`
  - `SubagentStarted`, `SubagentFinished`
  - `SessionCompleted`, `SessionFailed`

### 2. Claude Code (`claude`)
- **Executable**: `claude`
- **Modes**: Headless prompt / print mode

### 3. Gemini CLI (`gemini`)
- **Executable**: `gemini`
- **Modes**: Headless CLI prompt execution

### 4. Ollama (`ollama`)
- **Executable**: `ollama`
- **Modes**: Local open-weight models (Llama, DeepSeek, CodeLlama, etc.)
