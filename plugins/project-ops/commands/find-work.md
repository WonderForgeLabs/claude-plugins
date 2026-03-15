---
name: find-work
description: Find the next highest-priority unblocked issue to work on
allowed-tools:
  - Bash
---

Run the find-unblocked-work script to get a prioritized list of open, unblocked issues:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/find-unblocked-work.sh
```

Present the results as a prioritized list. Recommend the top item (highest priority, i.e., lowest P-number) as the suggested next issue to work on.

Offer to show blockers and full dependency details for any specific issue the user is interested in by running:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh <ISSUE_NUMBER>
```

If the script fails with "project_number not configured", tell the user to run `/configure` to set up their project board.
