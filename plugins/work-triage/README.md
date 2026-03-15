# work-triage

Triage open PRs and issues after completing epics — identify abandoned, superseded, or stale work items and recommend close/update/keep. Works with any GitHub repository.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install work-triage@wonderforgelabs-plugins
```

## Usage

### PR Triage

```
/pr-triage                          # Evaluate all open PRs
/pr-triage 42 87 123                # Evaluate specific PRs
/pr-triage --all --exclude 1270     # All PRs except #1270
```

Or trigger naturally: "triage PRs", "check stale PRs", "clean up PRs", "are these PRs still relevant"

### Issue Triage

```
/issue-triage                            # Evaluate all open issues
/issue-triage 42 87 123                  # Evaluate specific issues
/issue-triage --label bug                # Evaluate all open bugs
/issue-triage --all --exclude 50 60      # All issues except #50 and #60
```

Or trigger naturally: "triage issues", "groom backlog", "check stale issues", "are these issues still relevant"

### Setup

```
/work-triage:setup                   # Interactive wizard to bootstrap automation
/work-triage:setup --skip-board      # Skip project board check
```

Installs GitHub Actions workflows (issue intake, reopen audit) and project board helper scripts. Walks you through project board configuration and secrets setup.

## Philosophy

See [`references/how-we-work.md`](references/how-we-work.md) for the philosophy behind this plugin — the work graph model, lifecycle loop, automation conventions, and triage-as-graph-traversal principle.

## What It Does

### PR Triage (4 phases)

1. **Discovery** — lists open PRs with metadata (age, behind count, mergeable status, author)
2. **Parallel Evaluation** — dispatches one agent per PR in an isolated worktree to check rebase feasibility, overlapping changes on the default branch, and whether the work landed elsewhere
3. **Synthesis** — compiles results into a recommendation table (close/rework/rebase & merge/keep)
4. **Act** — offers to close, label, or comment on PRs with user approval for each action

### Issue Triage (4 phases)

1. **Discovery** — lists open issues with metadata (labels, assignee, linked PRs, project status, age)
2. **Parallel Evaluation** — dispatches agents to read issue content, search git history for references, check linked PRs, and search the codebase for completion evidence
3. **Synthesis** — compiles results into a recommendation table (close/update/split/unblock/keep)
4. **Act** — offers to close, update labels, add comments, or update project board status with user approval

## Requirements

- GitHub CLI (`gh`) authenticated
- Git

## Files

| File | Purpose |
|------|---------|
| `skills/pr-triage/SKILL.md` | PR triage skill with full workflow |
| `skills/pr-triage/references/evaluation-criteria.md` | PR evaluation decision matrix and signals |
| `skills/issue-triage/SKILL.md` | Issue triage skill with full workflow |
| `skills/issue-triage/references/evaluation-criteria.md` | Issue evaluation decision matrix and signals |
| `commands/pr-triage.md` | `/pr-triage` slash command |
| `commands/issue-triage.md` | `/issue-triage` slash command |
| `commands/setup.md` | `/work-triage:setup` interactive wizard |
| `references/how-we-work.md` | Philosophy and work model guide |
| `templates/workflows/` | GitHub Actions workflow templates |
| `templates/scripts/project/` | Project board helper scripts |
