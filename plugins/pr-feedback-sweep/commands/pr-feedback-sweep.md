---
name: pr-feedback-sweep
description: Scan open PRs for unresolved feedback and dispatch fix agents
argument-hint: "[PR numbers...] [--all]"
allowed-tools: ["Bash", "Read", "Agent", "Glob", "Grep"]
---

Invoke the pr-feedback-sweep skill.

**Targeting modes based on arguments:**

- **No arguments**: auto-detect the PR associated with the current branch. If none found, ask the user whether to scan all open PRs or exit.
- **`--all`**: scan all open PRs up to the configured `max_prs` limit.
- **Explicit PR numbers** (e.g. `965 988`): scan only those PRs. The `max_prs` limit does not apply. If both `--all` and explicit numbers are given, explicit numbers take precedence.

User input: $ARGUMENTS
