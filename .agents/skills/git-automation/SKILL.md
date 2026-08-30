---
name: git-automation
description: Semantic git branch management, conventional commit synthesis, pull request generation, diff formatting, and merge conflict resolution. Activate when performing git operations, reviewing diffs, creating commits, or pushing code.
---

# Git Automation & Workflow Skill

This skill outlines how agents should safely manage git repositories, format commits, inspect diffs, and handle branch lifecycles autonomously.

---

## 1. Conventional Commit Guidelines

All agent-generated commits must follow the **Conventional Commits** specification:

```
<type>(<scope>): <short summary>

[optional detailed body]
```

### Supported Types
- **`feat`**: New user-facing feature or API endpoint.
- **`fix`**: Bug fix, regression repair, or patch.
- **`refactor`**: Code change that neither fixes a bug nor adds a feature.
- **`style`**: UI redesign, theme updates, formatting changes.
- **`test`**: Adding missing unit tests or correcting test assertions.
- **`docs`**: Documentation, skill updates, or markdown improvements.

---

## 2. Safe Git Workflow Sequence

Before committing or pushing changes:
1. **Check Status**: Run `git status` to verify modified and untracked files.
2. **Review Diffs**: Run `git diff` to inspect changes and ensure no secrets or unintended edits exist.
3. **Stage Specific Files**: Run `git add <path>` (avoid blanket `git add .` unless creating a new project).
4. **Commit with Context**: Run `git commit -m "..."`.
5. **Push Guard**: Check remote branch status. Force pushes (`--force`) are strictly blocked unless user explicitly approves via mobile push.

---

## 3. Resolving Merge Conflicts

When merge conflicts occur:
1. Parse `<<<<<<< HEAD`, `=======`, and `>>>>>>> <branch>` conflict markers.
2. Synthesize both changes cleanly without losing functionality.
3. Remove all conflict markers.
4. Run compiler/tests to verify resolution before staging.
