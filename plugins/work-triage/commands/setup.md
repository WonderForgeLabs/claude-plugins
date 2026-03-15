---
name: setup
description: Bootstrap work-triage automation in a repo — install workflows, project board scripts, and configure project-ops
argument-hint: "[--skip-board]"
allowed-tools: ["AskUserQuestion", "Bash", "Read", "Write", "Glob", "Grep"]
---

# Work Triage Setup

You are guiding the user through bootstrapping the work-triage automation conventions in their repository. This installs GitHub Actions workflows, project board helper scripts, and wires up the project-ops configuration.

Read `${CLAUDE_PLUGIN_ROOT}/references/how-we-work.md` first to understand the philosophy you're setting up.

## Step 1: Auto-detect

Detect the current repo and what's already in place:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
```

Check for existing components:
- Does `.github/workflows/issue-intake.yml` exist?
- Does `.github/workflows/issue-reopen-audit.yml` exist?
- Does `scripts/project/` directory exist with `add-item.sh`, `set-field.sh`, `get-iterations.sh`?
- Does `.claude/project-ops.yaml` exist?

Present findings to the user:

```markdown
## Current State: {REPO}

| Component | Status |
|-----------|--------|
| Issue Intake workflow | Present / Missing |
| Issue Reopen Audit workflow | Present / Missing |
| Project board scripts | Present / Missing |
| project-ops config | Present / Missing |
```

Confirm this is the correct repo before proceeding.

## Step 2: Project Board

Use AskUserQuestion to ask ONE question:

**Question:** "Does this repo have a GitHub Projects V2 board?"
**Header:** "Board"
**Options:**
- **Yes, configured** — project-ops is already set up (skip board setup)
- **Yes, not configured** — board exists but project-ops hasn't been configured yet
- **No board** — need to create one

If "Yes, not configured": tell the user to run `/project-ops:configure` first, then re-run `/work-triage:setup`.

If "No board": tell the user to run `/project-ops:bootstrap` first, then re-run `/work-triage:setup`.

If `--skip-board` was passed in arguments, skip this step entirely.

## Step 3: Workflow Selection

Use AskUserQuestion — multi-select, ONE question:

**Question:** "Which automation workflows should we install?"
**Header:** "Workflows"
**multiSelect:** true
**Options:**
- **Issue Intake** — auto-labels new issues, assigns priority, wires into epics, detects blockers, hydrates project board
- **Issue Reopen Audit** — prevents closing epics with open sub-issues; runs on close events and every 12 hours

Skip any workflows that are already present (detected in Step 1). If all workflows are already present, skip this step and tell the user.

## Step 4: Secrets Check

Use AskUserQuestion — ONE question:

**Question:** "The workflows need these GitHub secrets. Are they configured?"
**Header:** "Secrets"
**Options:**
- **Both configured** — `CLAUDE_CODE_OAUTH_TOKEN` and `GH_PROJECTS_PAT` are set
- **Need help** — show me how to configure them
- **Skip for now** — I'll set them up later

If "Need help", explain:
- `CLAUDE_CODE_OAUTH_TOKEN`: Get from claude.ai account settings. Add via `gh secret set CLAUDE_CODE_OAUTH_TOKEN` or Settings > Secrets > Actions in the repo.
- `GH_PROJECTS_PAT`: Create a GitHub PAT (classic) with `project` scope for the org. Add via `gh secret set GH_PROJECTS_PAT` or Settings > Secrets > Actions.

## Step 5: Plan & Confirm

Show the user exactly what will happen:

```markdown
## Setup Plan

**Branch:** `chore/setup-work-triage-automation`

**Files to create:**
- `.github/workflows/issue-intake.yml` (from template)
- `.github/workflows/issue-reopen-audit.yml` (from template)
- `scripts/project/add-item.sh` (project board helper)
- `scripts/project/set-field.sh` (project board helper)
- `scripts/project/get-iterations.sh` (project board helper)

**Note:** These are opinionated templates from the WonderForgeLabs workflow.
You can customize them after the PR is created.

Proceed?
```

Only list files that will actually be created (skip existing ones). Wait for the user to confirm.

## Step 6: Execute

After user confirms:

```bash
# Create branch
git checkout -b chore/setup-work-triage-automation

# Create directories
mkdir -p .github/workflows scripts/project
```

Copy each selected file from the plugin templates:
```bash
# Workflows (only if selected and not already present)
cp "${CLAUDE_PLUGIN_ROOT}/templates/workflows/issue-intake.yml" .github/workflows/
cp "${CLAUDE_PLUGIN_ROOT}/templates/workflows/issue-reopen-audit.yml" .github/workflows/

# Project board scripts (only if not already present)
cp "${CLAUDE_PLUGIN_ROOT}/templates/scripts/project/add-item.sh" scripts/project/
cp "${CLAUDE_PLUGIN_ROOT}/templates/scripts/project/set-field.sh" scripts/project/
cp "${CLAUDE_PLUGIN_ROOT}/templates/scripts/project/get-iterations.sh" scripts/project/
chmod +x scripts/project/*.sh
```

Commit and push:
```bash
git add .github/workflows/ scripts/project/
git commit -m "chore: bootstrap work-triage automation workflows and scripts"
git push -u origin chore/setup-work-triage-automation
```

Open a PR:
```bash
gh pr create --title "chore: bootstrap work-triage automation" --body "## Summary
- Adds issue intake workflow (auto-label, priority, epic wiring, blocker detection)
- Adds issue reopen audit workflow (enforces sub-issue closure invariant)
- Adds project board helper scripts for GitHub Projects V2 API

## Required Secrets
- \`CLAUDE_CODE_OAUTH_TOKEN\` — for Claude Code Action
- \`GH_PROJECTS_PAT\` — org-scoped PAT with \`project\` scope

## Customization
These are opinionated templates. After merging, you can customize:
- Model choice in issue-intake.yml (default: claude-opus-4-6)
- Trusted bot list (default: claude[bot], copilot[bot])
- Audit cron schedule (default: every 12 hours)

See [How We Work](https://github.com/WonderForgeLabs/claude-plugins/blob/main/plugins/work-triage/references/how-we-work.md) for the philosophy behind these workflows."
```

## Step 7: Verify

Run inline checks:
```bash
# Workflow YAML is valid
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/issue-intake.yml'))" 2>&1 || echo "INVALID YAML: issue-intake.yml"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/issue-reopen-audit.yml'))" 2>&1 || echo "INVALID YAML: issue-reopen-audit.yml"

# Scripts are executable
test -x scripts/project/add-item.sh && echo "OK: add-item.sh" || echo "MISSING: add-item.sh"
test -x scripts/project/set-field.sh && echo "OK: set-field.sh" || echo "MISSING: set-field.sh"
test -x scripts/project/get-iterations.sh && echo "OK: get-iterations.sh" || echo "MISSING: get-iterations.sh"
```

Report results and the PR URL to the user.

## Idempotency

If everything is already in place, report "all set" and exit without changes. Don't create an empty branch or PR.

User input: $ARGUMENTS
