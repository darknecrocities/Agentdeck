---
name: remote-machine-control
description: Operational runbooks for remote workstation control, portable PTY terminal multiplexing, remote desktop screen streaming, webcam monitoring, app launching, audio synthesis, and file browsing. Activate when interacting with host hardware, desktop applications, or media streams.
---

# Remote Machine Control Skill

This skill provides protocols and API mappings for controlling host workstations remotely from mobile devices.

---

## 1. Remote App Launcher

AgentDeck allows 1-tap launching of applications on the host machine via `POST /api/system/launch-app`:

- **VS Code**: `app: "code"`, `path: "/path/to/project"`
- **Antigravity IDE**: `app: "antigravity"`, `path: "/path/to/project"`
- **Terminal / iTerm2**: `app: "terminal"`, `path: "/path/to/project"`
- **Google Chrome**: `app: "chrome"`, `url: "http://localhost:3000"`
- **Cursor**: `app: "cursor"`, `path: "/path/to/project"`

---

## 2. Low-Latency Screen & Webcam Streaming

- **Screen Capture**: Uses native OS APIs (`CGWindowListCreateImage` on macOS, DXGI on Windows, X11/PipeWire on Linux) streamed over WebSocket `/ws/screen` or HTTP MJPEG `/api/system/screenshot`.
- **Webcam Snapshot**: Captures live frames via AVFoundation/MediaFoundation for remote workspace monitoring (`/api/system/camera`).
- **Resource Guard**: Automatically halts streaming when client disconnects to prevent GPU/CPU drain.

---

## 3. Remote Audio & Text-to-Speech Synthesis

- **Speech Output**: Synthesize voice alerts on the host machine using native TTS engines (`say` on macOS, SAPI on Windows, `espeak` on Linux) via `POST /api/system/speak`.
- **Chimes & Alert Sounds**: Play notification pings when agent tasks finish or require human approval via `POST /api/system/play-sound`.

---

## 4. Host File System Browsing & Uploads

- **Browse**: `GET /api/system/browse?path=/dir` returns directories and file sizes.
- **Upload**: `POST /api/files/upload` streams images, assets, and source files from mobile storage into the target repository.
