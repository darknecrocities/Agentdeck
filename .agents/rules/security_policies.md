# Security & Access Control Policies

These security rules ensure safe autonomous execution across host machines.

---

## 1. Sandbox Traversal Protection
1. **Canonical Path Guard**: All filesystem operations must resolve canonical paths and ensure they remain inside allowed workspace roots unless explicit full-system permission is authorized.
2. **Secret File Masking**: Never print raw private keys (`id_rsa`, `id_ed25519`), `.env` secrets, or raw OAuth refresh tokens in logs or unmasked chat outputs.

---

## 2. Mandatory Approval Actions
The following actions require user authorization via mobile push before execution:
- `rm -rf <path>` (Recursive file deletion)
- `git push --force` or `git reset --hard`
- Shell execution with root or `sudo` privileges
- Modifying firewall or system network interface rules
