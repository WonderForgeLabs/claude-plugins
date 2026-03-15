---
name: update-roadmap
description: Update project board after completing work on an issue
argument-hint: "<issue-number>"
allowed-tools:
  - Bash
---

Takes an issue number as the argument. If no argument is provided, ask the user which issue number to close.

1. Source the config and close the issue:

```bash
source ${CLAUDE_PLUGIN_ROOT}/scripts/project-config.sh
gh issue close {NUMBER} --repo "$PROJECT_OPS_OWNER_REPO"
```

2. Check what the closed issue was blocking:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh {NUMBER}
```

3. For each issue listed in the "Blocking:" section, check if it is now fully unblocked by running:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh {BLOCKED_ISSUE_NUMBER}
```

An issue is fully unblocked when all of its "Blocked by:" entries are CLOSED.

4. Report to the user:
   - Confirmation that the issue was closed
   - List of issues that were blocking on the closed issue
   - Which of those are now **fully unblocked** and ready for work
   - Which remain blocked (and by what open issues)
