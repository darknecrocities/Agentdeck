---
name: vibe-scaffolding
description: Automated scaffolding and architecture setup for new full-stack, mobile, frontend, and backend projects (Flutter, Next.js, Rust Axum, Python FastAPI, Vite/React). Activate when scaffolding new projects, bootstrapping repositories, or setting up project boilerplate from mobile.
---

# Vibe Scaffolding Skill

This skill allows autonomous coding agents to scaffold production-grade applications rapidly from mobile voice or text prompts with zero manual configuration.

---

## 1. Supported Stacks & Scaffolding Commands

### Flutter Mobile (iOS, Android, macOS, Web)
```bash
flutter create --org com.agentdeck --platforms=android,ios,macos,web <app_name>
cd <app_name>
flutter pub add google_fonts http shared_preferences
```

### Rust Backend (Axum + Tokio + SQLite)
```bash
cargo new --bin <app_name>
cd <app_name>
cargo add axum tokio --features tokio/full
cargo add serde serde_json --features serde/derive
cargo add rusqlite uuid chrono tracing tracing-subscriber
```

### Modern Web App (Vite + React / Next.js)
```bash
npx -y create-vite@latest <app_name> --template react-ts
cd <app_name>
npm install
npm install lucide-react clsx tailwindcss
```

### Python Service (FastAPI + Uvicorn)
```bash
mkdir -p <app_name> && cd <app_name>
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn pydantic requests
```

---

## 2. Scaffolding Checklist for Agents

When scaffolding any project for a vibecoding user:
1. **Directory Structure**: Create standard folders (`lib/`, `src/`, `components/`, `services/`, `models/`, `routes/`).
2. **Theme & Design System**: Immediately write a cohesive theme file (`theme.dart` or `index.css`) with obsidian/dark mode aesthetics.
3. **Environment & Git**: Create `.gitignore`, `.env.example`, and initialize git repository.
4. **Health Check / Test**: Provide a smoke test or `/health` endpoint to verify compilation.
5. **Auto-Launch**: Start the dev server in the background and notify the user with the port/URL.
