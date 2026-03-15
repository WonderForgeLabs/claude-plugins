---
name: manage-dependencies
description: Use when creating issues that have blocking relationships, setting up epic dependency chains, or when user asks to "block", "unblock", or manage issue dependencies. Also use proactively after creating multiple related issues to wire up their dependency graph.
---

# Manage Dependencies

Manage native GitHub issue dependency relationships (blocked-by / blocking) using the project-ops scripts.

## When to Use

- After creating related issues (e.g., epic breakdown with phased dependencies)
- When user says "X is blocked by Y" or "set up blockers"
- When refactoring dependency chains after closing or splitting issues
- Proactively after `/project-ops:find-work` reveals stale or missing blockers

## Step 1: Inspect Current Dependencies

Before adding or removing dependencies, check the current state:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh <ISSUE_NUMBER>
```

This shows:
- **Blocked by:** issues that must be completed before this one
- **Blocking:** issues waiting on this one
- **Sub-issues:** child issues
- **Parent:** parent epic

## Step 2: Add Blocked-By Relationships

Set issue A as blocked by issue B (A cannot start until B is done):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh <blocked-issue> <blocking-issue>
```

Example — issue #1040 is blocked by #1037:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh 1040 1037
```

### Batch Pattern for Epic Breakdowns

When setting up a phased epic, wire dependencies in order:

```
Phase 1: #A, #B (no blockers — ready to start)
Phase 2: #C, #D (blocked by Phase 1)
Phase 3: #E (blocked by Phase 2)
```

```bash
# Phase 2 blocked by Phase 1
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh C A
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh C B
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh D A
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh D B

# Phase 3 blocked by Phase 2
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh E C
${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh E D
```

## Step 3: Remove Dependencies

Remove a blocked-by relationship when it's no longer needed:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/remove-blocker.sh <blocked-issue> <blocking-issue>
```

## Step 4: Verify the Dependency Graph

After making changes, verify the graph is correct by inspecting each issue:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh <ISSUE_NUMBER>
```

Check that:
- No circular dependencies exist
- Phase ordering is correct (earlier phases don't depend on later ones)
- Follow-up / out-of-scope issues are blocked by the epic or final phase

## Quick Reference

| Script | Usage | Description |
|--------|-------|-------------|
| `show-blockers.sh <issue>` | `show-blockers.sh 1040` | Show all relationships for an issue |
| `add-blocker.sh <blocked> <blocker>` | `add-blocker.sh 1040 1037` | Set 1040 as blocked by 1037 |
| `remove-blocker.sh <blocked> <blocker>` | `remove-blocker.sh 1040 1037` | Remove the blocking relationship |
