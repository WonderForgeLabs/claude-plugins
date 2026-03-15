---
name: update-roadmap
description: Use when completing work on an issue, closing issues, or needing to update the project board. Also use after merging PRs to check what got unblocked.
---

# Update Roadmap

Update the project board after completing work on an issue. Close the issue, discover what was blocked by it, and report newly unblocked work.

## Step 1: Close the Issue

Close the completed issue. Detect org/repo from the project config or git remote:

```bash
gh issue close {NUMBER} --repo {org/repo}
```

Use `$PROJECT_OPS_OWNER_REPO` from the config if available, or detect from `git remote get-url origin`.

## Step 2: Check What Was Blocked

Run the show-blockers script to see the blocking relationships of the closed issue:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh {NUMBER}
```

Look at the **"Blocking:"** section of the output. Each issue listed there was waiting on this issue to complete.

## Step 3: Check If Blocked Issues Are Now Fully Unblocked

For each issue that was blocked by the now-closed issue, run the show-blockers script on that issue:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh {BLOCKED_ISSUE_NUMBER}
```

An issue is now fully unblocked if **all** of its blockedBy entries have state CLOSED. If it still has OPEN blockers, it remains blocked.

## Step 4: Report Results

Summarize to the user:
- Which issue was closed
- Which issues were blocking (the "Blocking" list from step 2)
- Which of those are now **fully unblocked** and ready to work on
- Which remain blocked (and by what)

## Relationship Management Scripts

Use these scripts to adjust issue relationships as needed:

| Script | Usage | Description |
|--------|-------|-------------|
| `${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh <blocked> <blocking>` | `add-blocker.sh 788 786` | Set issue 788 as blocked by 786 |
| `${CLAUDE_PLUGIN_ROOT}/scripts/remove-blocker.sh <blocked> <blocking>` | `remove-blocker.sh 788 786` | Remove the blocking relationship |
| `${CLAUDE_PLUGIN_ROOT}/scripts/add-sub-issue.sh <parent> <child>` | `add-sub-issue.sh 700 788` | Add 788 as a sub-issue of 700 |
