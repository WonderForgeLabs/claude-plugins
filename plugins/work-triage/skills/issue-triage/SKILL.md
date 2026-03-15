---
name: issue-triage
description: "This skill should be used when the user asks to \"triage issues\", \"check stale issues\", \"review open issues\", \"clean up backlog\", \"are these issues still relevant\", \"groom backlog\", \"prioritize backlog\", \"review backlog\", or after completing a large epic. Evaluates open issues against the codebase and git history to identify completed, stale, or unblocked work. Works in tandem with the pr-triage skill."
---

# Issue Triage

Evaluate open issues to determine which are completed, stale, blocked, or still relevant. Dispatches parallel agents to analyze each issue against the codebase and git history.

**This skill works in tandem with pr-triage.** When evaluating issues, cross-reference open and merged PRs to understand the full picture: an issue may appear open but a PR already landed the work; a PR may look stale but its linked issue reveals active planning. If the user has also requested PR triage, coordinate findings between both skills. Use all available context: source code on main, PR diffs/titles/descriptions/review feedback, issue contents/comments, markdown docs, and any memory tools available.

## Setup

### Detect Repository and Default Branch

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
```

All commands in this workflow use `$REPO` and `$DEFAULT_BRANCH` (instead of hardcoding `main`).

### Check for Issue Intake Automation

If the repo has `.github/workflows/issue-intake.yml`, the repo uses automated issue intake:
- Issues are auto-labeled with area, type, and priority labels
- Issues are added to a GitHub Projects V2 board with fields: Status, Priority, Critical Path, Sprint
- Issues may be wired into epics via GitHub sub-issues API
- Blockers are documented as comments ("Blocked by #X")
- Closed issues are audited by `issue-reopen-audit.yml` — if sub-issues remain open, the parent is auto-reopened with an `audit:reopened` label

Factor these signals into evaluation:
- Project board status "Done" with issue still open = likely needs closing
- `audit:reopened` label = was closed prematurely, has open sub-issues
- `needs-triage` label = intake hasn't run yet, skip or re-trigger intake instead
- Epic issues with open sub-issues should not be closed even if the epic description is satisfied

## Workflow

### Determine Target Issues

Parse the arguments to determine targeting mode:

1. **No arguments or `--all`** — scan all open issues:
   ```bash
   gh issue list --repo "$REPO" --state open --json number,title,labels,assignees,createdAt,updatedAt --limit 100
   ```

2. **`--label <label>`** — filter by label:
   ```bash
   gh issue list --repo "$REPO" --state open --label "{LABEL}" --json number,title,labels,assignees,createdAt,updatedAt --limit 100
   ```

3. **Explicit issue numbers** (e.g. `42 87 123`) — evaluate only those:
   ```bash
   gh issue view {NUMBER} --repo "$REPO" --json number,title,labels,assignees,createdAt,updatedAt,body,comments
   ```

4. **`--exclude <numbers>`** — fetch all, then remove excluded numbers from the list.

If both explicit numbers and `--all` are given, explicit numbers take precedence.

### Phase 1: Discovery

For each issue in the target list, gather metadata:

```bash
# Get linked PRs
gh api "repos/$REPO/issues/{NUMBER}/timeline" \
  --jq '[.[] | select(.event == "cross-referenced") | .source.issue | select(.pull_request != null) | {number: .number, state: .state, title: .title}]' 2>/dev/null || echo "[]"

# Get project board status (if using GitHub Projects)
gh issue view {NUMBER} --repo "$REPO" --json projectItems -q '.projectItems[].status.name' 2>/dev/null || echo "none"

# Check for sub-issues (epic detection)
OWNER=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        subIssues(first: 50) {
          totalCount
          nodes { number title state }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO_NAME" -F number={NUMBER} 2>/dev/null || echo "{}"
```

Present a summary table to the user:

```markdown
| # | Issue | Title | Labels | Assignee | Age | Last Updated | Linked PRs | Sub-Issues |
|---|-------|-------|--------|----------|-----|-------------|------------|------------|
```

If the user specified explicit issue numbers, `--label`, or `--exclude` flags, proceed with those. Otherwise, if scanning all open issues and the count exceeds 10, ask the user to confirm which to evaluate. For smaller lists, proceed with all.

### Phase 2: Parallel Evaluation

Before dispatching agents, read `references/evaluation-criteria.md` for the full decision matrix, completion/staleness signal tables, blocked/unblocked detection patterns, and evidence quality standards. Incorporate these criteria into agent instructions.

Dispatch one agent per issue (or batch of small issues) using the Agent tool. Each agent needs access to `Bash`, `Read`, `Grep`, and `Glob` tools.

**Each agent receives these instructions** (substitute all `{PLACEHOLDERS}` with actual values before dispatching):

> You are evaluating issue #{NUMBER} for relevance against the current state of the codebase.
>
> 1. **Read the issue:**
>    ```bash
>    gh issue view {NUMBER} --repo {REPO} --json title,body,comments,labels
>    ```
>    Understand what work was requested.
>
> 2. **Search for references in git history:**
>    ```bash
>    # Commits referencing this issue number
>    git log origin/$DEFAULT_BRANCH --all --oneline --grep="#{NUMBER}" | head -20
>    # Separate search for title keywords (OR semantics with multiple --grep)
>    git log origin/$DEFAULT_BRANCH --all --oneline --grep="{KEYWORD1}" --grep="{KEYWORD2}" | head -20
>    ```
>
> 3. **Check linked PRs:**
>    ```bash
>    # Were linked PRs merged or closed?
>    gh api "repos/{REPO}/issues/{NUMBER}/timeline" \
>      --jq '[.[] | select(.event == "cross-referenced") | .source.issue | select(.pull_request != null) | {number: .number, state: .state}]'
>    ```
>    For merged PRs, check if they actually addressed the issue or just referenced it.
>
> 4. **Check sub-issues (if this is an epic):**
>    ```bash
>    OWNER=$(echo "{REPO}" | cut -d/ -f1)
>    REPO_NAME=$(echo "{REPO}" | cut -d/ -f2)
>    gh api graphql -f query='
>      query($owner: String!, $repo: String!, $number: Int!) {
>        repository(owner: $owner, name: $repo) {
>          issue(number: $number) {
>            subIssues(first: 50) {
>              totalCount
>              nodes { number title state }
>            }
>          }
>        }
>      }' -f owner="$OWNER" -f repo="$REPO_NAME" -F number={NUMBER}
>    ```
>    If open sub-issues exist, the epic should NOT be closed.
>
> 5. **Search the codebase:**
>    Use Grep and Glob to search for keywords from the issue title/body.
>    Check if the described feature exists, the bug was fixed, or the refactoring was done.
>
> 6. **Check for blocked/unblocked status:**
>    If the issue mentions being blocked by another issue:
>    ```bash
>    gh issue view {BLOCKER_NUMBER} --repo {REPO} --json state -q .state
>    ```
>
> 7. **Assess completion status:**
>    - **Fully done**: All described work exists on the default branch. Cite evidence.
>    - **Partially done**: Some work landed, some remains. List what's complete and what's remaining with specific details.
>    - **Not done**: No evidence of the work on the default branch.
>    For partial completion, estimate percentage and describe remaining work items.
>
> 8. **Report back** with:
>    - Status: `completed` | `partially-done` | `stale` | `blocked` | `unblocked` | `relevant`
>    - Evidence: what you found (commits, PRs, code locations)
>    - Completion: if partially done, what % is complete and what specific items remain
>    - Sub-issues: open/closed counts if this is an epic
>    - Recommendation: one of `close-completed`, `close-irrelevant`, `update`, `split`, `unblock`, `keep`
>    - Reasoning: 2-3 sentences explaining why

### Phase 3: Synthesis

Collect all agent results and compile into a summary table:

```markdown
## Issue Triage Results

| Issue | Title | Labels | Age | Linked PRs | Evidence | Completion | Recommendation |
|-------|-------|--------|-----|------------|----------|------------|----------------|
| #42 | Add widget API | feature | 30d | #55 (merged) | Widget API at src/api/widgets.ts | 100% | Close (completed) |
| #87 | Fix auth timeout | bug | 60d | None | Auth module rewritten in #102 | N/A | Close (irrelevant) |
| #99 | Add rate limiting | feature | 10d | #100 (open) | Blocked by #98 (now closed) | 0% | Unblock |
| #150 | Refactor platform | chore | 20d | #160 (merged) | Entity types done, API pending | 60% | Update |
```

**Recommendation categories:**

- **Close (completed)** — work is done. Cite the commit, PR, or code location that proves it.
- **Close (irrelevant)** — no longer relevant due to architectural changes, scope shifts, or the underlying problem being eliminated. Explain why.
- **Update** — issue scope or description needs revision. For partially-done work, list what's complete and what remains. Suggest updated description.
- **Split** — issue is too large or covers multiple concerns. Suggest sub-issues.
- **Unblock** — blocking issue was resolved. The issue is ready to work on.
- **Keep** — still accurate, relevant, and actionable. No changes needed.

For partially-done issues, always include:
- What's complete (with evidence: commit, PR, code location)
- What remains (specific work items)
- Whether the remaining work should stay on this issue or be split into new issues

### Phase 4: Act (with user approval)

Present the recommendations and ask the user what actions to take. Available actions:

1. **Close issues** — close with a comment explaining why:
   ```bash
   gh issue close {NUMBER} --repo "$REPO" --comment "Closing: {REASON}. Evidence: {DETAILS}"
   ```

2. **Update labels** — add or remove labels:
   ```bash
   gh issue edit {NUMBER} --repo "$REPO" --add-label "stale"
   gh issue edit {NUMBER} --repo "$REPO" --remove-label "blocked"
   ```
   If the repo uses issue intake automation, trigger re-triage by adding `needs-triage` label instead of manually adjusting labels.

3. **Add comments** — add context or updated scope:
   ```bash
   gh issue comment {NUMBER} --repo "$REPO" --body "{COMMENT}"
   ```

4. **Update project board** — change status if using GitHub Projects:
   Use the `project-ops` plugin patterns if available.

5. **Update issue description** — for partially-done issues, offer to update the body with a checklist showing completed vs remaining items.

**CRITICAL: Never close or modify an issue without explicit user approval.** Present all recommendations, let the user pick which to execute.

## Usage

```
/issue-triage                            # Evaluate all open issues
/issue-triage 42 87 123                  # Evaluate specific issues
/issue-triage --label bug                # Evaluate all open bugs
/issue-triage --all --exclude 50 60      # All issues except #50 and #60
```
