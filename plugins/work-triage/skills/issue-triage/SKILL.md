---
name: issue-triage
description: "This skill should be used when the user asks to \"triage issues\", \"check stale issues\", \"review open issues\", \"clean up backlog\", \"are these issues still relevant\", \"groom backlog\", \"prioritize backlog\", \"review backlog\", or after completing a large epic. Evaluates open issues against the codebase and git history to identify completed, stale, or unblocked work."
---

# Issue Triage

Evaluate open issues to determine which are completed, stale, blocked, or still relevant. Dispatches parallel agents to analyze each issue against the codebase and git history.

## Setup

### Detect Repository

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

All commands below use `$REPO`.

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
```

Present a summary table to the user:

```markdown
| # | Issue | Title | Labels | Assignee | Age | Last Updated | Linked PRs |
|---|-------|-------|--------|----------|-----|-------------|------------|
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
>    # Commits referencing this issue
>    git log origin/main --all --oneline --grep="#{NUMBER}" --grep="{ISSUE_TITLE_KEYWORDS}" | head -20
>    ```
>
> 3. **Check linked PRs:**
>    ```bash
>    # Were linked PRs merged or closed?
>    gh api "repos/{REPO}/issues/{NUMBER}/timeline" \
>      --jq '[.[] | select(.event == "cross-referenced") | .source.issue | select(.pull_request != null) | {number: .number, state: .state}]'
>    ```
>
> 4. **Search the codebase:**
>    Use Grep and Glob to search for keywords from the issue title/body.
>    Check if the described feature exists, the bug was fixed, or the refactoring was done.
>
> 5. **Check for blocked/unblocked status:**
>    If the issue mentions being blocked by another issue:
>    ```bash
>    gh issue view {BLOCKER_NUMBER} --repo {REPO} --json state -q .state
>    ```
>
> 6. **Assess and recommend:**
>    - Is the described work done? (cite evidence — commit, PR, code location)
>    - Is it partially done? What remains?
>    - Has the scope changed since the issue was filed?
>    - Is it still relevant given the current architecture?
>
> 7. **Report back** with:
>    - Status: `completed` | `partially-done` | `stale` | `blocked` | `unblocked` | `relevant`
>    - Evidence: what you found (commits, PRs, code)
>    - Recommendation: one of `close-completed`, `close-irrelevant`, `update`, `split`, `unblock`, `keep`
>    - Reasoning: 2-3 sentences explaining why

### Phase 3: Synthesis

Collect all agent results and compile into a summary table:

```markdown
## Issue Triage Results

| Issue | Title | Labels | Age | Linked PRs | Evidence | Recommendation |
|-------|-------|--------|-----|------------|----------|----------------|
| #42 | Add widget API | feature | 30d | #55 (merged) | Widget API exists at src/api/widgets.ts | Close (completed) |
| #87 | Fix auth timeout | bug | 60d | None | Auth module rewritten in #102 | Close (irrelevant) |
| #99 | Add rate limiting | feature | 10d | #100 (open) | Blocked by #98 (now closed) | Unblock |
```

**Recommendation categories:**

- **Close (completed)** — work is done. Cite the commit, PR, or code location that proves it.
- **Close (irrelevant)** — no longer relevant due to architectural changes, scope shifts, or the underlying problem being eliminated. Explain why.
- **Update** — issue scope or description needs revision. List what changed and suggest new description.
- **Split** — issue is too large or covers multiple concerns. Suggest sub-issues.
- **Unblock** — blocking issue was resolved. The issue is ready to work on.
- **Keep** — still accurate, relevant, and actionable. No changes needed.

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

3. **Add comments** — add context or updated scope:
   ```bash
   gh issue comment {NUMBER} --repo "$REPO" --body "{COMMENT}"
   ```

4. **Update project board** — change status if using GitHub Projects:
   Use the `project-ops` plugin patterns if available.

**CRITICAL: Never close or modify an issue without explicit user approval.** Present all recommendations, let the user pick which to execute.

## Usage

```
/issue-triage                            # Evaluate all open issues
/issue-triage 42 87 123                  # Evaluate specific issues
/issue-triage --label bug                # Evaluate all open bugs
/issue-triage --all --exclude 50 60      # All issues except #50 and #60
```
