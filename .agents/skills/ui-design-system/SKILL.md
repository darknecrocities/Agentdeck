---
name: ui-design-system
description: Obsidian titanium monochrome design system specification, color tokens, micro-animations, typography, ASCII progress meters, and premium mobile/web UI standards for AgentDeck applications. Activate when designing or modifying user interfaces, components, widgets, or styles.
---

# UI Design System & Aesthetics Skill

This skill enforces the Obsidian Monochrome design language across all AgentDeck interfaces.

---

## 1. Palette & Surface Tokens

| Token Name | Hex Code | Purpose |
|---|---|---|
| **Background** | `#000000` | True Pitch Black canvas |
| **Surface Deep** | `#080808` | Inset containers, code blocks, dark cards |
| **Surface Card** | `#0C0C0C` | Primary cards, panels, list tiles |
| **Surface Elevated** | `#141414` | Floating modals, dropdowns, headers |
| **Border Dark** | `#1E1E1E` | Subtle hairline dividers |
| **Border Card** | `#262626` | Standard titanium card boundaries |
| **Border Light** | `#404040` | Focused or hovered element borders |
| **Text Pure White** | `#FFFFFF` | Primary headings, titles, active labels |
| **Text Silver** | `#E2E8F0` | High-contrast secondary text |
| **Text Zinc** | `#A3A3A3` | Informational subtitles, metadata |
| **Text Muted** | `#666666` | Disabled states, timestamps |
| **Functional Green** | `#51CF66` | Online, success, added lines (`+`) |
| **Functional Amber** | `#FFD43B` | Pending approvals, command alerts |
| **Functional Red** | `#FF6B6B` | Errors, panics, deleted lines (`-`) |

---

## 2. Typography Rules
- **Font Family**: Google Fonts `JetBrains Mono` for all monospace metrics, logs, code diffs, and headers.
- **Font Weights**:
  - `w900` / `w800`: Section headers, status badges, uppercase pills.
  - `w600` / `w700`: Card titles, filenames, timestamps.
  - `w400` / `w500`: Code contents, regular text, descriptions.

---

## 3. Micro-Animations & Interactivity
- **Radar Pulse**: Subtle concentric green ripple for live Tailscale mesh connectivity.
- **Breathing Glow**: Gentle scale (`0.95x` to `1.05x`) and glow pulse on mascot and app emblem during thinking/boot states.
- **ASCII Progress Meters**: Sleek monospace visual bars (`[████████░░░░░░░░░░] 45%`) for CPU and Memory load.
- **Haptic/Visual Feedback**: Distinct active indicators (`ACTIVE` white pill, `ONLINE` green badge, `OFFLINE` zinc badge).
