---
name: pr-triage
description: "This skill should be used when the user asks to \"triage PRs\", \"check stale PRs\", \"review open PRs\", \"clean up PRs\", \"are these PRs still relevant\", \"split this PR\", or after completing a large epic with many parallel branches. Evaluates open PRs against main to identify abandoned, superseded, or stale work. Works in tandem with the issue-triage skill."
---

# PR Triage

Evaluate open PRs to determine which are stale, superseded, conflicted, or ready to merge. Dispatches parallel agents to analyze each PR in an isolated worktree.

**This skill works in tandem with issue-triage.** When evaluating PRs, cross-reference linked issues to understand the full picture: a PR may look stale but its linked issue reveals it's blocked; an issue may appear open but a PR already landed the work. If the user has also requested issue triage, coordinate findings between both skills. Use all available context: source code on main, PR diffs/titles/descriptions/review feedback, linked issue contents, markdown docs, and any memory tools available.

## Setup

### Detect Repository

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

All commands in this workflow use `$REPO`.

### Check for Issue Intake Automation

If the repo has `.github/workflows/issue-intake.yml`, the repo uses automated issue intake with labels, project board fields, epic/sub-issue wiring, and blocker detection. Respect those conventions:
- Issues have structured labels (area labels, priority, type)
- Issues may be wired into epics via GitHub sub-issues
- Issues may have project board status (Todo, In Progress, Done, etc.)
- Closed issues are audited for open sub-issues via `issue-reopen-audit.yml`

Factor these signals into PR evaluation — a PR linked to an issue with project board status "Done" is likely already completed.

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
# How far behind main (base=main, head=branch, behind_by = commits on main not on branch)
BRANCH=$(gh pr view {NUMBER} --json headRefName -q .headRefName)
gh api "repos/$REPO/compare/main...$BRANCH" --jq '.behind_by' 2>/dev/null || echo "unknown"

# Mergeable status
gh pr view {NUMBER} --repo "$REPO" --json mergeable -q .mergeable

# Check if author is a bot
gh pr view {NUMBER} --repo "$REPO" --json author -q '.author.login'

# Get linked issues
gh pr view {NUMBER} --repo "$REPO" --json body -q '.body' | grep -oE '#[0-9]+' | head -10
```

Present a summary table to the user:

```markdown
| # | PR | Title | Author | Age | Behind Main | Mergeable | Linked Issues |
|---|-----|-------|--------|-----|-------------|-----------|---------------|
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
>    git rebase origin/main 2>&1 || true
>    git rebase --abort 2>/dev/null || true
>    ```
>    Record: clean rebase or conflict count/files.
>
> 2. **Read the PR diff and extract files:**
>    ```bash
>    gh pr diff {NUMBER} --repo {REPO}
>    FILES=$(gh pr diff {NUMBER} --repo {REPO} --name-only)
>    ```
>    Identify the key files, functions, and classes modified.
>
> 3. **Check for overlapping changes on main:**
>    ```bash
>    # Get PR creation date
>    CREATED=$(gh pr view {NUMBER} --repo {REPO} --json createdAt -q .createdAt)
>    # Find commits on main touching the same files since PR was created
>    git log origin/main --since="$CREATED" --oneline -- $FILES
>    ```
>
> 4. **Search for the same code on main:**
>    For each function/class name modified in the PR, search main using Grep.
>    Note: also check `git log --diff-filter=R -- {FILE}` for renamed files.
>    This detects if the work landed via a different PR.
>
> 5. **Check linked issues:**
>    Read the PR description and look for linked issue numbers (`#NNN`).
>    For each linked issue, check its state and project board status:
>    ```bash
>    gh issue view {ISSUE_NUMBER} --repo {REPO} --json state,labels,projectItems -q '{state: .state, labels: [.labels[].name], project_status: [.projectItems[].status.name]}'
>    ```
>    A linked issue marked "Done" on the project board or closed with a different PR is strong evidence the work landed elsewhere.
>
> 6. **Check PR review feedback:**
>    ```bash
>    gh api "repos/{REPO}/pulls/{NUMBER}/reviews" --jq '[.[] | {user: .user.login, state: .state}]'
>    ```
>    Note any requested changes or approvals. Unaddressed review feedback affects the recommendation.
>
> 7. **Assess and recommend:**
>    - Was this work done in another PR? (cite the commit/PR)
>    - Is the code still applicable or has the surrounding code changed significantly?
>    - Are conflicts minor (just rebase needed) or major (architectural drift)?
>    - Is there unaddressed review feedback?
>    - For partially-done work: what percentage is complete? What remains?
>
> 8. **Report back** with:
>    - Status: `clean` | `minor-conflicts` | `major-conflicts`
>    - Overlap: description of what landed on main
>    - Completion: percentage complete if partially done, what remains
>    - Review state: approved / changes-requested / pending
>    - Recommendation: one of `close-completed`, `close-superseded`, `rework`, `split`, `rebase-and-merge`, `keep`
>    - Reasoning: 2-3 sentences explaining why

### Phase 3: Synthesis

Collect all agent results and compile into a summary table:

```markdown
## PR Triage Results

| PR | Title | Author | Age | Behind | Status | Overlap | Recommendation |
|----|-------|--------|-----|--------|--------|---------|----------------|
| #42 | Add widget | user | 14d | 23 | conflicts | Widget added in #55 | Close (completed) |
| #87 | Fix auth | user | 3d | 2 | clean | None | Rebase & merge |
| #200 | Mega refactor | user | 7d | 5 | clean | Partial | Split |
```

**Recommendation categories:**

- **Close (completed)** — work already landed on main. Cite the commit or PR that did it.
- **Close (superseded)** — architectural changes make this PR irrelevant. Explain what changed.
- **Rework** — concept still valid but needs significant updates. List what needs changing.
- **Split** — PR is too large or covers multiple concerns. See "Splitting Mega PRs" below.
- **Rebase & merge** — still good, just needs a rebase. Note conflict severity if any.
- **Keep** — actively in progress or recently updated. Leave alone.

For partially-done PRs, include a "Completion" column showing what's done vs remaining.

### Phase 3.5: Splitting Mega PRs

When a PR is recommended for splitting, walk the user through the process interactively:

1. **Analyze the PR's changes by concern:**
   Group the modified files into logical units (e.g., "new entity types", "API endpoints", "test coverage", "refactoring", "documentation"). Present this grouping to the user.

2. **Propose split plan:**
   ```markdown
   ### Proposed Split for PR #{NUMBER}
   | # | New PR Scope | Files | Dependencies |
   |---|-------------|-------|-------------|
   | 1 | Add entity types | src/Entities/*.cs | None |
   | 2 | Add API endpoints | src/Api/*.cs | Depends on #1 |
   | 3 | Add tests | tests/*.cs | Depends on #1, #2 |
   ```

3. **Get user approval for the split plan.** Adjust groupings based on feedback.

4. **For each approved split, create the branch and PR:**
   Ask the user for permission before each step:
   - Create a new branch from main
   - Cherry-pick or apply relevant changes
   - Push and create a new PR linking to the original
   - Add a comment on the original PR referencing the splits

5. **Close the original PR** (with user approval) with a comment listing all split PRs.

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

4. **Split PRs** — initiate the splitting workflow for mega PRs (see Phase 3.5).

**CRITICAL: Never close or modify a PR without explicit user approval.** Present all recommendations, let the user pick which to execute.

## Bot PR Patterns

When evaluating bot-authored PRs, apply these heuristics (see `references/evaluation-criteria.md` for full details):

- **copilot-swe-agent**: Check if the described issue was fixed by a human PR. Often abandoned when the human fix landed first.
- **dependabot[bot]**: Check if the dependency was updated in a different PR or if the version is now outdated.
- **renovate[bot]**: Same as dependabot.

## Usage

```
/pr-triage                          # Evaluate all open PRs
/pr-triage 42 87 123                # Evaluate specific PRs
/pr-triage --all --exclude 1270     # All PRs except #1270
```
