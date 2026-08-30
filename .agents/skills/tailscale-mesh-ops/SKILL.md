---
name: tailscale-mesh-ops
description: Operating guide for Tailscale WireGuard mesh networking, MagicDNS resolution, firewall port forwarding, and multi-node workstation routing for AgentDeck mobile connectivity. Activate when configuring Tailscale nodes, diagnosing connection latency, or setting up remote host tunnels.
---

# Tailscale Mesh Operations Skill

This skill provides complete operational runbooks for securely connecting mobile clients to local workstation daemons over Tailscale with zero open public ports.

---

## 1. Network Topology & Port Mapping

- **Tailscale IP Range**: `100.64.0.0/10` (CGNAT range, e.g. `100.x.y.z`).
- **Daemon Default Port**: `8765` (HTTP REST API and WebSocket streams).
- **MagicDNS Format**: `<device-name>.<tailnet-name>.ts.net:8765`.
- **Latency Target**: Sub-50ms round-trip ping for low-latency PTY terminals and video streaming.

---

## 2. Workstation Host Setup Runbooks

### macOS
```bash
# Verify Tailscale status and IP
tailscale ip -4
tailscale status

# Start daemon on port 8765
cd /Users/arronkianparejas/agentdeck
cargo run --bin agentdeckd
```

### Windows (PowerShell)
```powershell
# Get Tailscale IP
tailscale ip -4

# Allow inbound port 8765 on Windows Firewall
New-NetFirewallRule -DisplayName "AgentDeck Daemon" -Direction Inbound -LocalPort 8765 -Protocol TCP -Action Allow

# Start daemon
cargo run --bin agentdeckd
```

### Linux (Ubuntu / Debian / Arch)
```bash
# Ensure Tailscale is active
sudo tailscale up
tailscale ip -4

# Allow port 8765 in UFW
sudo ufw allow 8765/tcp

# Start daemon
cargo run --bin agentdeckd
```

---

## 3. Connectivity Diagnostics & Troubleshooting

When a mobile device cannot connect to a host node:
1. **Ping Check**: Execute `tailscale ping <target-ip>` to verify WireGuard tunnel reachability.
2. **Health Check**: Run `curl -v http://100.x.y.z:8765/health` to confirm the Axum server is responding.
3. **Binding Check**: Ensure `agentdeckd` is listening on `0.0.0.0:8765` (not strictly `127.0.0.1`).
4. **Key Expiry**: Check if Tailscale machine key has expired in the Tailscale admin console.
