---
name: pr-triage
description: Triage open PRs — identify stale, superseded, or abandoned PRs and recommend actions
argument-hint: "[PR numbers...] [--all] [--exclude <numbers>]"
allowed-tools: ["Bash", "Read", "Agent", "Glob", "Grep"]
---

# PR Triage

Evaluate open PRs to determine which are stale, superseded, or ready to merge.

Invoke the `pr-triage` skill to get the full workflow, then follow it.

**Targeting modes based on arguments:**

- **No arguments**: scan all open PRs in the current repository.
- **`--all`**: same as no arguments — scan all open PRs.
- **Explicit PR numbers** (e.g. `42 87 123`): evaluate only those PRs.
- **`--exclude <numbers>`**: skip specific PRs when scanning all (e.g. `--all --exclude 1270 1280`).

User input: $ARGUMENTS
