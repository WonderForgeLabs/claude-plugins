# How We Work

A field guide to the work model that drives triage, planning, and execution across the plugin ecosystem.

## The Work Graph

Issues, PRs, epics, sub-issues, blockers, and code on the default branch are nodes in a connected graph. When you look at any work item, you follow edges — you don't read the item in isolation.

A PR links to issues. Those issues have sub-issues and blockers. Those blockers have their own PRs. Code on the default branch is the ground truth for whether any of this work is actually done.

This means: never evaluate a PR without checking its linked issues. Never evaluate an issue without checking its linked PRs. The item you're looking at is one projection of a larger piece of work — the graph tells you what's really going on.

## The Lifecycle Loop

All work follows a continuous cycle:

```
find-work → implement → pr-feedback-sweep → merge → update-roadmap → work-triage → find-work
```

Each station in the loop maps to a plugin:

- **project-ops** drives `find-work` (pick highest-priority unblocked issue) and `update-roadmap` (close issue, discover what's unblocked)
- **pr-feedback-sweep** drives the quality gate (scan for unresolved review feedback, dispatch fix agents)
- **work-triage** drives evaluation and cleanup (identify stale/superseded/completed work, recommend actions)

No plugin operates in isolation. The output of one is the input to the next. When `update-roadmap` closes an issue and unblocks three others, `find-work` picks the highest-priority one. When `work-triage` identifies a completed PR, it checks the linked issue to see if that should be closed too.

## Automation Conventions

The repo's existing machinery maintains the work graph automatically:

- **`issue-intake.yml`** — runs on new issues and `needs-triage` label events. Auto-labels with area/type/priority, assigns to a sprint, wires into epics via the GitHub sub-issues API, detects blockers, and hydrates the project board with Status, Priority, Critical Path, and Sprint fields.
- **`issue-reopen-audit.yml`** — enforces a hard invariant: you cannot close an issue while its sub-issues are still open. Runs on every close event and on a 12-hour cron. Reopens issues with open sub-issues and adds the `audit:reopened` label.
- **Project board fields** (Status, Priority, Critical Path, Sprint) are the source of truth for where work stands. Not issue labels, not PR status — the board.
- **Labels have automated meanings**: `needs-triage` triggers re-intake, `audit:reopened` means premature closure was detected, `blocked` means a dependency is not met.

Don't fight these conventions. Read from them, respect them, use them.

Not all repos will have these conventions in place. The `/work-triage:setup` command bootstraps them. When triaging a repo without these automations, the skills degrade gracefully — they use what's available (git history, PR state, issue state) and skip project-board-specific signals.

## Triage as Graph Traversal

This is the core operating principle. When evaluating any work item:

- **Follow all edges before making a recommendation.** A PR's linked issues tell you whether the work is done, blocked, or superseded. An issue's linked PRs tell you whether code landed or was abandoned.
- **Code on the default branch is the authoritative signal** for "is this actually complete?" Not the issue status, not the PR label — the code.
- **Track degree of completion.** Percentage done, remaining items, not just binary done/not-done. After big epics, partial completion is the norm. Surface what remains rather than making a blunt close/keep call.
- **Large PRs need decomposition, not labels.** A mega-PR covering 10 concerns shouldn't get a "stale" label. It needs splitting into focused PRs — walk the user through the groupings, get approval for each split.
- **When uncertain, keep.** Closing something prematurely wastes more work than leaving it open. Add a comment asking the author for status rather than guessing.

## Agent Collaboration

How agents work together in this system:

- **Parallel agents in isolated worktrees** for PR evaluation. Each agent gets a self-contained task with all placeholders substituted — it doesn't need to know about the other agents or the overall triage session.
- **Issue evaluation agents** search git history, linked PRs, and the codebase for completion evidence. They don't modify anything.
- **User approval gates** before any destructive action. Close, label, comment — all require explicit confirmation. The agent recommends; the user decides.
- **Skills are the shared language.** They encode decision-making criteria (evaluation matrices, signal tables, decision trees), not just commands to run. An agent reading the skill knows *how to think about* a PR, not just what `gh` commands to call.
- **Cross-reference everything.** PR triage checks issue state. Issue triage checks PR state. Both check code on the default branch. The graph is the truth; follow the edges.
