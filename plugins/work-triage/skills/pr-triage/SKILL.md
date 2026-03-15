---
name: pr-triage
description: "This skill should be used when the user asks to \"triage PRs\", \"check stale PRs\", \"review open PRs\", \"clean up PRs\", \"are these PRs still relevant\", or after completing a large epic with many parallel branches. Evaluates open PRs against main to identify abandoned, superseded, or stale work."
---

# PR Triage

Evaluate open PRs to determine which are stale, superseded, conflicted, or ready to merge. Dispatches parallel agents to analyze each PR in an isolated worktree.

## Setup

### Detect Repository

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

All commands below use `$REPO`.

## Workflow

### Determine Target PRs

Parse the arguments to determine targeting mode:

1. **No arguments or `--all`** — scan all open PRs:
   ```bash
   gh pr list --repo "$REPO" --state open --json number,title,headRefName,author,createdAt,updatedAt --limit 100
   ```

2. **Explicit PR numbers** (e.g. `42 87 123`) — evaluate only those:
   ```bash
   gh pr view {NUMBER} --repo "$REPO" --json number,title,headRefName,author,createdAt,updatedAt
   ```

3. **`--exclude <numbers>`** — fetch all, then remove excluded numbers from the list.

If both explicit numbers and `--all` are given, explicit numbers take precedence.

### Phase 1: Discovery

For each PR in the target list, gather metadata:

```bash
# How far behind main
gh api "repos/$REPO/compare/$(gh pr view {NUMBER} --json headRefName -q .headRefName)...main" \
  --jq '.ahead_by' 2>/dev/null || echo "unknown"

# Mergeable status
gh pr view {NUMBER} --repo "$REPO" --json mergeable -q .mergeable

# Check if author is a bot
gh pr view {NUMBER} --repo "$REPO" --json author -q '.author.login'
```

Present a summary table to the user:

```markdown
| # | PR | Title | Author | Age | Behind Main | Mergeable |
|---|-----|-------|--------|-----|-------------|-----------|
```

If the user specified explicit PR numbers or `--exclude` flags, proceed with those. Otherwise, if scanning all open PRs and the count exceeds 10, ask the user to confirm which to evaluate. For smaller lists, proceed with all.

### Phase 2: Parallel Evaluation

Before dispatching agents, read `references/evaluation-criteria.md` for the full decision matrix, staleness/superseded signal tables, bot PR patterns, and conflict severity definitions. Incorporate these criteria into agent instructions.

Dispatch one agent per PR using the Agent tool. Each agent MUST use `isolation: "worktree"` to work on an isolated copy. Each agent needs access to `Bash`, `Read`, `Grep`, and `Glob` tools.

**Each agent receives these instructions** (substitute all `{PLACEHOLDERS}` with actual values before dispatching):

> You are evaluating PR #{NUMBER} (`{BRANCH}`) for staleness against main.
>
> 1. **Check rebase feasibility:**
>    ```bash
>    git fetch origin {BRANCH} main
>    git checkout {BRANCH}
>    git rebase origin/main --no-commit --no-stat 2>&1 || true
>    git rebase --abort 2>/dev/null || true
>    ```
>    Record: clean rebase or conflict count/files.
>
> 2. **Read the PR diff:**
>    ```bash
>    gh pr diff {NUMBER} --repo {REPO}
>    ```
>    Identify the key files, functions, and classes modified.
>
> 3. **Check for overlapping changes on main:**
>    ```bash
>    # Get PR creation date
>    CREATED=$(gh pr view {NUMBER} --repo {REPO} --json createdAt -q .createdAt)
>    # Find commits on main touching the same files since PR was created
>    git log origin/main --since="$CREATED" --oneline -- {FILES_FROM_DIFF}
>    ```
>
> 4. **Search for the same code on main:**
>    For each function/class name modified in the PR, search main:
>    ```bash
>    git show origin/main:{FILE_PATH} 2>/dev/null | grep -c "{FUNCTION_NAME}" || echo "0"
>    ```
>    This detects if the work landed via a different PR.
>
> 5. **Assess and recommend:**
>    - Was this work done in another PR? (cite the commit/PR)
>    - Is the code still applicable or has the surrounding code changed significantly?
>    - Are conflicts minor (just rebase needed) or major (architectural drift)?
>
> 6. **Report back** with:
>    - Status: `clean` | `minor-conflicts` | `major-conflicts`
>    - Overlap: description of what landed on main
>    - Recommendation: one of `close-completed`, `close-superseded`, `rework`, `rebase-and-merge`, `keep`
>    - Reasoning: 2-3 sentences explaining why

### Phase 3: Synthesis

Collect all agent results and compile into a summary table:

```markdown
## PR Triage Results

| PR | Title | Author | Age | Behind | Status | Overlap | Recommendation |
|----|-------|--------|-----|--------|--------|---------|----------------|
| #42 | Add widget | user | 14d | 23 | conflicts | Widget added in #55 | Close (completed) |
| #87 | Fix auth | user | 3d | 2 | clean | None | Rebase & merge |
```

**Recommendation categories:**

- **Close (completed)** — work already landed on main. Cite the commit or PR that did it.
- **Close (superseded)** — architectural changes make this PR irrelevant. Explain what changed.
- **Rework** — concept still valid but needs significant updates. List what needs changing.
- **Rebase & merge** — still good, just needs a rebase. Note conflict severity if any.
- **Keep** — actively in progress or recently updated. Leave alone.

### Phase 4: Act (with user approval)

Present the recommendations and ask the user what actions to take. Available actions:

1. **Close PRs** — close with a comment explaining why:
   ```bash
   gh pr close {NUMBER} --repo "$REPO" --comment "Closing: {REASON}. Evidence: {DETAILS}"
   ```

2. **Add labels** — mark PRs that need attention:
   ```bash
   gh pr edit {NUMBER} --repo "$REPO" --add-label "needs-rebase"
   gh pr edit {NUMBER} --repo "$REPO" --add-label "stale"
   ```

3. **Leave comments** — add context without closing:
   ```bash
   gh pr comment {NUMBER} --repo "$REPO" --body "{COMMENT}"
   ```

**CRITICAL: Never close or modify a PR without explicit user approval.** Present all recommendations, let the user pick which to execute.

## Bot PR Patterns

When evaluating bot-authored PRs, apply these heuristics:

- **copilot-swe-agent**: Check if the described issue was fixed by a human PR. Often abandoned when the human fix landed first.
- **dependabot[bot]**: Check if the dependency was updated in a different PR or if the version is now outdated.
- **renovate[bot]**: Same as dependabot.

## Usage

```
/pr-triage                          # Evaluate all open PRs
/pr-triage 42 87 123                # Evaluate specific PRs
/pr-triage --all --exclude 1270     # All PRs except #1270
```
