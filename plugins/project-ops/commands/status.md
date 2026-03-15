---
name: status
description: Show project board status overview
allowed-tools:
  - Bash
---

Run both of the following scripts and present the combined results to the user with a brief summary:

1. Run the project status script to get items grouped by critical path with priority and blocked/unblocked status:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh
```

2. Run the find-unblocked-work script to get the prioritized list of actionable items:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/find-unblocked-work.sh
```

Present the results in two sections:
- **Board Overview**: the critical-path-grouped output from project-status.sh, summarizing how many items are in each critical path and how many are blocked vs unblocked.
- **Ready to Work**: the unblocked items from find-unblocked-work.sh, highlighting the top priorities.

If either script fails with "project_number not configured", tell the user to run `/configure` to set up their project board.
