# Global Coding Standards for Autonomous Agents

These rules govern all automated code generation, refactoring, and tool execution in AgentDeck workspaces.

---

## 1. Quality & Architecture
1. **Zero-Warning Principle**: All generated code must compile cleanly with `flutter analyze`, `cargo check`, and `tsc` with zero errors and zero warnings.
2. **Minimal & Surgical Edits**: Use targeted `replace_file_content` edits rather than rewriting whole files. Preserve existing comments, types, and unrelated logic.
3. **Async Context Safety**: In Flutter, never use `BuildContext` across an `await` without verifying `if (!mounted) return;` or storing the navigator/scaffold messenger beforehand.
4. **Deprecation Immunity**: Never use deprecated APIs or properties (e.g. use `initialValue` in `DropdownButtonFormField`, `activeThumbColor` in `Switch`, and `.toARGB32()` in `Color`).

---

## 2. Testing & Verification
1. **Automated Validation**: Always run the respective test suite (`flutter test`, `cargo test`, `npm test`) after modifying logic.
2. **Regression Guards**: When fixing an issue, verify that previously passing tests continue to pass.
