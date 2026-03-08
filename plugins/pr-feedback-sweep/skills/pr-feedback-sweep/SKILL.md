---
name: pr-feedback-sweep
description: Fetch all unresolved review feedback across open PRs and dispatch fix agents
disable-model-invocation: true
---

# PR Feedback Sweep

Scan all open PRs for unresolved review feedback and dispatch agents to fix them.

## Setup

Detect the current repository dynamically:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

All commands below use `$REPO` — this skill works with any GitHub repository.

## Workflow

### Phase 1: Discover Open PRs

```bash
gh pr list --repo "$REPO" --state open --json number,title,headRefName --limit 30
```

### Phase 2: Fetch Feedback for Each PR

For each open PR, gather ALL feedback sources:

1. **Issue comments** (general discussion):
   ```bash
   gh api "repos/$REPO/issues/{NUMBER}/comments" \
     --jq '.[] | {id: .id, user: .user.login, created_at: .created_at, body: .body}'
   ```

2. **Review comments** (inline code comments):
   ```bash
   gh api "repos/$REPO/pulls/{NUMBER}/comments" \
     --jq '.[] | {id: .id, user: .user.login, path: .path, line: .line, created_at: .created_at, body: .body}'
   ```

3. **Reviews** (approval/request changes):
   ```bash
   gh api "repos/$REPO/pulls/{NUMBER}/reviews" \
     --jq '.[] | {id: .id, user: .user.login, state: .state, body: .body}'
   ```

If the GitHub API is rate limited, use the MCP tools instead:
- `mcp__plugin_github_github__pull_request_read` with `method: get_comments`
- `mcp__plugin_github_github__pull_request_read` with `method: get_review_comments`
- `mcp__plugin_github_github__pull_request_read` with `method: get_reviews`

### Phase 3: Compile Summary

Present a table organized by PR:

```markdown
## PR #XXX — Title (branch: branch-name)
| # | Source | User | File:Line | Feedback |
|---|--------|------|-----------|----------|
| 1 | review | copilot | src/foo.ts:28 | Description of finding |
| 2 | comment | claude-code | — | Description of comment |
```

Skip feedback that is:
- From the PR author acknowledging a comment (e.g., "fixed", "done", "addressed")
- Already resolved review threads
- Bot comments (CI status, coverage reports)

### Phase 4: Dispatch Fix Agents

For each PR with unresolved feedback, offer to dispatch a fix agent:

1. **Identify the worktree** — check if one exists at `.claude/worktrees/` for the branch
2. **If no worktree exists** — create one from the PR branch:
   ```bash
   git fetch origin {branch}
   git worktree add .claude/worktrees/{short-name} origin/{branch}
   ```
3. **Install dependencies** — if the repo has a dependency installation step (e.g., `package.json`, `requirements.txt`, `go.mod`), run the appropriate install command in the worktree
4. **Dispatch agent** with:
   - Specific feedback items to fix
   - Worktree path
   - Instruction to run tests locally before pushing
   - Instruction to commit and push when done

### Phase 5: Monitor

After dispatching, report:
- How many PRs had feedback
- How many agents dispatched
- Agent IDs for tracking

## Rate Limit Handling

If GitHub API returns 403 rate limit:
1. Check reset time from the error message
2. If < 5 minutes, wait and retry
3. If > 5 minutes, use MCP GitHub tools (separate rate limit pool)
4. If both limited, report the situation and suggest retrying later

## Usage

```
/pr-feedback-sweep           # Full sweep of all open PRs
/pr-feedback-sweep 965 988   # Sweep specific PRs only
```
