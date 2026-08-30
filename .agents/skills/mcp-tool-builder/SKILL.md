---
name: mcp-tool-builder
description: Guide for authoring, registering, and integrating custom Model Context Protocol (MCP) tool servers, sidecars, and JSON schemas for autonomous agents. Activate when extending agent toolsets, writing custom tool definitions, or integrating external APIs via MCP.
---

# MCP Tool Builder & Extension Skill

This skill explains how to build and expose custom Model Context Protocol (MCP) tools that autonomous agents can invoke from the AgentDeck control plane.

---

## 1. MCP Standard Architecture

An MCP server exposes a JSON-RPC interface over stdin/stdout or SSE (Server-Sent Events) implementing three main primitives:
1. **Tools**: Executable functions with JSON schema inputs.
2. **Resources**: Read-only contextual data (files, database tables, logs).
3. **Prompts**: Parameterized reusable prompts for user workflows.

---

## 2. Standard Tool Definition Schema

Every tool registered in AgentDeck must supply a clean JSON schema:

```json
{
  "name": "query_database",
  "description": "Execute read-only SQL queries against the local SQLite database.",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "The SQL query to execute (SELECT only)."
      },
      "limit": {
        "type": "integer",
        "description": "Maximum number of rows to return (default 50)."
      }
    },
    "required": ["query"]
  }
}
```

---

## 3. Registering Custom MCP Servers

Add custom sidecars and MCP servers to `~/.gemini/antigravity/mcp_config.json` or `.agents/mcp_config.json`:

```json
{
  "mcpServers": {
    "git-tools": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git", "/Users/arronkianparejas/agentdeck"]
    },
    "sqlite-tools": {
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "/Users/arronkianparejas/agentdeck/agentdeck.db"]
    }
  }
}
```

---

## 4. MCP Security & Approval Rules
- **Safe Tools** (`SELECT`, `GET`, `read_file`, `list_dir`): Auto-executed without interrupting the user.
- **Side-Effect Tools** (`UPDATE`, `POST`, `deploy`, `drop`): Suspended until approved via mobile push.
