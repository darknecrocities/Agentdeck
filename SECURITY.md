# AgentDeck Security Policy & Architecture

## Security Principles

1. **Local-First & Private Networking**:
   - Default network mode binds exclusively to `127.0.0.1` and/or the Tailscale interface (`100.x.y.z`).
   - The daemon does not expose listening sockets to the public internet.

2. **Authentication & Authorization**:
   - Every REST request and WebSocket connection requires a bearer authentication token (`Authorization: Bearer <token>`) configured in `agentdeck.toml` or via `AGENTDECK_AUTH_TOKEN`.
   - Device pairing and cryptographic token rotation are supported.

3. **Path Traversal Protection**:
   - All filesystem operations are strictly confined within explicitly registered project roots.
   - Any path attempting directory traversal (`../`, absolute paths outside roots, symlink escapes) is rejected immediately with `403 Forbidden`.

4. **Approval System for Dangerous Operations**:
   - Actions with security implications (e.g. `sudo`, `rm -rf`, `git push --force`, `git reset --hard`, arbitrary command execution) enter an `AWAITING_APPROVAL` state.
   - Agents pause execution until an explicit approval token is signed via the mobile app or CLI.

5. **Credential & Secret Protection**:
   - Secrets, API keys, passwords, and private tokens are masked and redacted from logs, database records, and event payloads before transmission over WebSockets.
