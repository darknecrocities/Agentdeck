---
name: vibe-debugging
description: Comprehensive diagnostic and automated root-cause repair engine for compilation errors, runtime panics, broken unit tests, dependency conflicts, and Flutter/Rust/Web regressions. Activate when fixing bugs, solving test failures, or troubleshooting logs.
---

# Vibe Debugging & Auto-Remediation Skill

This skill equips agents with systematic debugging methodologies to diagnose, isolate, and fix errors autonomously while streaming explanations to the user's mobile device.

---

## 1. The 4-Step Debugging Loop

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  1. Capture  │ ──► │  2. Isolate  │ ──► │   3. Patch   │ ──► │  4. Verify   │
│ (Logs/Stack) │     │ (Root Cause) │     │ (Min Edit)   │     │ (Re-run Test)│
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

1. **Capture**: Inspect the exact stderr, panic trace, or compiler diagnostic (line number, column, error code).
2. **Isolate**: View the surrounding context of the offending file (`view_file` with line range).
3. **Patch**: Apply targeted, minimal fixes using `replace_file_content` without rewriting unrelated logic.
4. **Verify**: Re-run the compiler or test suite immediately (`flutter test`, `cargo test`, `npm test`) to ensure zero regressions.

---

## 2. Common Language Gotchas & Remediation

### Flutter / Dart
- **`use_build_context_synchronously`**: Guard all `BuildContext` uses across async gaps with `if (!mounted) return;` or capture `Navigator.of(context)` before the `await`.
- **Deprecated Widget Properties**:
  - `DropdownButtonFormField`: Use `initialValue` instead of `value`.
  - `Switch`: Use `activeThumbColor` or `activeTrackColor` instead of `activeColor`.
  - `Color`: Use `.toARGB32()` instead of deprecated `.value`.

### Rust
- **Unused `mut` / Variables**: Remove unnecessary `mut` keywords or prefix with `_`.
- **Borrow Checker & Lifetime Conflicts**: Use `Arc<Mutex<T>>` or `.clone()` where appropriate across async tasks.
- **Error Handling**: Use `?` operator or `.map_err(...)` rather than `.unwrap()` in daemon handlers.

### TypeScript / Node.js
- **Missing Module / Types**: Run `npm install --save-dev @types/<pkg>`.
- **Async / Promise Mismatch**: Ensure `await` is present on all async operations and promises are properly handled.
