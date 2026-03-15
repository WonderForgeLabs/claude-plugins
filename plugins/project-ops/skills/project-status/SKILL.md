---
name: project-status
description: Use when checking roadmap progress, viewing what's blocked, seeing sprint contents, or getting an overview of a GitHub project board. Also use when user asks "what's the status" or "where are we".
---

# Project Status

Provide a comprehensive overview of the GitHub Project V2 board by running the scripts below. Use `${CLAUDE_PLUGIN_ROOT}/scripts/` as the base path for all scripts.

## Overview by Critical Path

Run the project status script to see all items grouped by critical path, with priority and blocked/unblocked status:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh
```

## Milestone Progress

Run the milestone progress script to see open/closed counts and due dates per milestone:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/milestone-progress.sh
```

## Items Grouped by Status

Run the items-by-status script to see every board item grouped by its status column (Todo, In Progress, Done, etc.):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/items-by-status.sh
```

## Unblocked Work

Run the find-unblocked-work script to see open issues that have zero open blockers, sorted by priority:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/find-unblocked-work.sh
```

## Issue Relationships

Run the show-blockers script to inspect blocking/blocked-by/sub-issue relationships for a specific issue:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/show-blockers.sh <ISSUE_NUMBER>
```

## View Configurations

Run the project-views script to see all configured views (layout, filters, grouping, sorting):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/project-views.sh
```

## Relationship Management Scripts

Use these scripts to manage issue relationships on the board:

| Script | Usage | Description |
|--------|-------|-------------|
| `${CLAUDE_PLUGIN_ROOT}/scripts/add-blocker.sh <blocked> <blocking>` | `add-blocker.sh 788 786` | Set issue 788 as blocked by 786 |
| `${CLAUDE_PLUGIN_ROOT}/scripts/remove-blocker.sh <blocked> <blocking>` | `remove-blocker.sh 788 786` | Remove the blocking relationship |
| `${CLAUDE_PLUGIN_ROOT}/scripts/add-sub-issue.sh <parent> <child>` | `add-sub-issue.sh 700 788` | Add 788 as a sub-issue of 700 |

## Troubleshooting

If any script fails with **"project_number not configured"**, the project board has not been linked yet. Direct the user to run `/configure` to set up their project board connection.
