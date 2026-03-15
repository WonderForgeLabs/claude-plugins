---
description: Triage open issues — identify completed, stale, or unblocked issues and recommend actions
argument-hint: "[issue numbers...] [--all] [--label <label>] [--exclude <numbers>]"
allowed-tools: ["Bash", "Read", "Agent", "Glob", "Grep"]
---

# Issue Triage

Evaluate open issues to determine which are completed, stale, or ready to work on.

Invoke the `issue-triage` skill to get the full workflow, then follow it.

**Targeting modes based on arguments:**

- **No arguments**: scan all open issues in the current repository.
- **`--all`**: same as no arguments — scan all open issues.
- **`--label <label>`**: filter issues by label (e.g. `--label bug`).
- **Explicit issue numbers** (e.g. `42 87 123`): evaluate only those issues.
- **`--exclude <numbers>`**: skip specific issues when scanning all (e.g. `--all --exclude 50 60`).

User input: $ARGUMENTS
