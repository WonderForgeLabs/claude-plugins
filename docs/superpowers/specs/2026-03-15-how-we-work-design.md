# Design: "How We Work" Philosophy + Setup Command for work-triage

## Problem

After completing epics with parallel agents, the forge repo accumulates stale PRs, orphaned issues, and disconnected work items. The `work-triage` plugin evaluates these — but it lacks two things:

1. A **philosophy document** that codifies why triage works the way it does, shared across both skills and available to any future plugin that needs to understand the work model.
2. A **setup command** that bootstraps the automation conventions (GitHub Actions workflows, project board, secrets) in new repos so the triage skills have the structured graph they depend on.

## Design

### Part 1: `references/how-we-work.md`

A plugin-level reference document at `work-triage/references/how-we-work.md`. Both `pr-triage` and `issue-triage` skills point to it. Tone: field guide with strong opinions — practical and direct, convictions expressed through specifics rather than declarations.

**Five sections (~150-200 words each, ~800-1000 words total):**

#### Section 1: The Work Graph

Issues, PRs, epics, sub-issues, blockers, and code on main are nodes in a connected graph. When you look at any work item, you follow edges — you don't read the item in isolation. A PR links to issues; those issues have sub-issues and blockers; those blockers have their own PRs. Code on main is the ground truth for whether any of this work is actually done.

#### Section 2: The Lifecycle Loop

All work follows a continuous cycle:

```
find-work → implement → pr-feedback-sweep → merge → update-roadmap → work-triage → find-work
```

Maps to plugins: `project-ops` drives find-work and update-roadmap. `pr-feedback-sweep` (in the claude-plugins marketplace) drives the quality gate. `work-triage` drives the evaluation/cleanup. Each plugin is a station in the loop — none operates in isolation.

#### Section 3: Automation Conventions

The repo's existing machinery maintains the work graph:
- `issue-intake.yml` — auto-labels, assigns priority, wires epics, detects blockers, hydrates project board
- `issue-reopen-audit.yml` — enforces closure invariant: can't close an epic with open sub-issues; runs on close events and 12-hour cron
- Project board fields (Status, Priority, Critical Path, Sprint) are the source of truth
- Labels have automated meanings: `needs-triage` triggers re-intake, `audit:reopened` means premature closure detected, `blocked` means dependency not met

Don't fight these conventions. Read from them, respect them, use them.

**Note:** Not all repos will have these conventions in place. The `/work-triage:setup` command bootstraps them. When triaging a repo without these automations, the skills degrade gracefully — they use what's available (git history, PR state, issue state) and skip project-board-specific signals.

#### Section 4: Triage as Graph Traversal

The core operating principle. When evaluating any work item:
- Follow all edges before making a recommendation
- A PR's linked issues tell you whether the work is done, blocked, or superseded
- An issue's linked PRs tell you whether code landed or was abandoned
- Code on main is the authoritative signal for "is this actually complete?"
- Track degree of completion — percentage done, remaining items, not just binary done/not-done
- Large PRs need decomposition guidance (splitting into focused PRs), not just a "stale" label
- Partial completion is the norm after big epics — surface what remains, don't just close or keep

#### Section 5: Agent Collaboration

How agents work together in this system:
- Parallel agents in isolated worktrees for PR evaluation — each gets a self-contained task with all placeholders substituted
- Issue evaluation agents search git history, linked PRs, and the codebase for completion evidence
- User approval gates before any destructive action (close, label, comment)
- Skills are the shared language — they encode decision-making criteria, not just commands to run
- Cross-reference everything: PR triage checks issue state, issue triage checks PR state

### Part 2: Setup Command (`/work-triage:setup`)

An interactive wizard command that bootstraps the automation conventions in a target repo.

**File:** `commands/setup.md`

**Allowed tools:** `AskUserQuestion`, `Bash`, `Read`, `Write`, `Glob`, `Agent`

**Workflow (questions one at a time, auto-detect first):**

#### Step 1: Auto-detect

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Check what already exists:
- `.github/workflows/issue-intake.yml` present?
- `.github/workflows/issue-reopen-audit.yml` present?
- `scripts/project/` directory present?
- `.claude/project-ops.yaml` present?
- `project-ops` plugin installed?

Present findings to the user. Confirm repo is correct.

#### Step 2: Project Board (AskUserQuestion)

"Does this repo have a GitHub Projects V2 board?"
- **Yes, it's configured** — skip board setup
- **Yes, but not configured for project-ops** — offer to run `/project-ops:configure`
- **No** — offer to run `/project-ops:bootstrap` to create one

#### Step 3: Workflow Selection (AskUserQuestion, multi-select)

"Which automation workflows should we install?"
- **Issue Intake** — auto-label, priority, epic wiring, blocker detection
- **Issue Reopen Audit** — enforce sub-issue closure invariant

Show what each does (from the descriptions in how-we-work.md). Skip any already present.

#### Step 4: Secrets Check (AskUserQuestion)

"These workflows need GitHub secrets. Have you configured them?"
- `CLAUDE_CODE_OAUTH_TOKEN` — for Claude Code Action
- `GH_PROJECTS_PAT` — for project board API access (org-scoped)

Provide guidance on how to create each if missing. Link to relevant docs.

#### Step 5: Plan & Confirm

Show the user exactly what will happen:
- Files to be created/copied (list each file)
- Branch name
- PR title

Ask for confirmation before proceeding.

#### Step 6: Execute

- Create a branch (`chore/setup-work-triage-automation`)
- Copy workflow templates from `${CLAUDE_PLUGIN_ROOT}/templates/workflows/` to `.github/workflows/`
- Copy project board helper scripts from `${CLAUDE_PLUGIN_ROOT}/templates/scripts/project/` to `scripts/project/` (see Part 3 for the full list)
- If `.claude/project-ops.yaml` doesn't exist and project-ops is configured, generate it from the project board's current field structure
- Commit and push
- Open a PR with a description explaining what was installed and what secrets are needed

#### Step 7: Verify

Run inline checks (no subagent needed — these are simple validations):
- Workflow files are valid YAML (`yq` or `python -c 'import yaml; ...'`)
- Required scripts exist alongside workflows
- Required secrets are documented in the PR description
- No conflicting workflows exist (e.g., a different issue-intake workflow)

Report results to user.

### Part 3: Templates

**Location:** `work-triage/templates/`

```
templates/
├── workflows/
│   ├── issue-intake.yml
│   └── issue-reopen-audit.yml
└── scripts/
    └── project/
        ├── add-item.sh
        ├── set-field.sh
        ├── get-iterations.sh
        ├── project-config.sh       # Shared config loader
        └── README.md               # Documents what each script does
```

#### Workflow templates

Copied from the forge repo's `.github/workflows/`. These are **opinionated templates**, not generic scaffolds:
- They use `claude-opus-4-6` as the model for issue intake
- They allow `claude[bot]` and `copilot[bot]` as trusted bots
- They reference specific project board field names (Status, Priority, Critical Path, Sprint)
- The intake prompt is structured around a specific workflow (duplicate detection → labeling → board hydration → epic wiring → blocker evaluation)

The setup command copies them as-is. Repos that need customization can edit the workflows after the PR is created — the templates are a strong starting point, not a locked-down framework.

#### Project board helper scripts

The workflow templates call `./scripts/project/add-item.sh`, `./scripts/project/set-field.sh`, and `./scripts/project/get-iterations.sh` to interact with the GitHub Projects V2 GraphQL API. These scripts are **required dependencies** — the workflows will fail without them.

Source: the forge repo's `scripts/project/` directory. These are thin wrappers around `gh api graphql` that read field IDs from `.claude/project-ops.yaml`.

**Critical dependency chain:**
1. Workflows call `./scripts/project/*.sh`
2. Scripts read `.claude/project-ops.yaml` for field IDs
3. `project-ops.yaml` is generated by `/project-ops:configure`

The setup command must ensure all three layers are in place.

### Part 4: Skill Updates

Both `pr-triage/SKILL.md` and `issue-triage/SKILL.md` get a new line in their Phase 2 preamble, inserted immediately after the existing "read `references/evaluation-criteria.md`" line:

> Also read `../../references/how-we-work.md` for the philosophy governing these evaluations — especially the principles on graph traversal and partial completion tracking.

### Updated Plugin Structure

```
work-triage/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── references/
│   └── how-we-work.md                          # NEW: Philosophy doc
├── templates/
│   ├── workflows/
│   │   ├── issue-intake.yml                     # NEW: Workflow template
│   │   └── issue-reopen-audit.yml               # NEW: Workflow template
│   └── scripts/
│       └── project/
│           ├── add-item.sh                      # NEW: Project board script
│           ├── set-field.sh                     # NEW: Project board script
│           ├── get-iterations.sh                # NEW: Project board script
│           ├── project-config.sh                # NEW: Shared config loader
│           └── README.md                        # NEW: Script docs
├── commands/
│   ├── pr-triage.md
│   ├── issue-triage.md
│   └── setup.md                                 # NEW: Interactive wizard
├── skills/
│   ├── pr-triage/
│   │   ├── SKILL.md                             # UPDATED: points to how-we-work.md
│   │   └── references/
│   │       └── evaluation-criteria.md
│   └── issue-triage/
│       ├── SKILL.md                             # UPDATED: points to how-we-work.md
│       └── references/
│           └── evaluation-criteria.md
```

## Implementation Order

1. Write `references/how-we-work.md`
2. Update both skills to reference it
3. Copy workflow templates from forge repo to `templates/workflows/`
4. Copy project board scripts from forge repo to `templates/scripts/project/`
5. Write `commands/setup.md` (interactive wizard)
6. Update README with setup command docs
7. Update marketplace description if needed
8. Validate with plugin-validator agent
9. Review skills with skill-reviewer agent
10. Commit and push to PR

## Dependencies

- `project-ops` plugin should be installed in the target repo for full functionality (the setup command checks and guides the user through installation if missing)
- Workflows require two GitHub secrets: `CLAUDE_CODE_OAUTH_TOKEN` and `GH_PROJECTS_PAT`
- Workflows call `scripts/project/*.sh` which read `.claude/project-ops.yaml` — the setup command ensures all three layers (workflows → scripts → config) are deployed together
- The `pr-feedback-sweep` plugin (already in the claude-plugins marketplace) is referenced in the lifecycle loop but is not a hard dependency — repos without it still work, they just skip the quality gate step

## Portability Notes

The workflow templates are opinionated — they encode a specific workflow philosophy (the one described in `how-we-work.md`). They are not designed to be generic scaffolds that work for any repo without modification. Repos that adopt this system are adopting the philosophy, not just the YAML files.

Customization points after setup:
- Model choice in `issue-intake.yml` (default: `claude-opus-4-6`)
- Trusted bot list (default: `claude[bot]`, `copilot[bot]`)
- Priority levels and Critical Path areas in the intake prompt
- Audit cron schedule in `issue-reopen-audit.yml` (default: every 12 hours)

## Idempotency

Running `/work-triage:setup` a second time is safe:
- Step 1 detects what's already present and reports it
- Step 3 skips workflows that already exist
- Step 6 only copies files that are missing
- If everything is already in place, the command reports "all set" and exits without changes
