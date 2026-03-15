---
name: pr-feedback-sweep
description: Fetch all unresolved review feedback across open PRs and dispatch fix agents
---

# PR Feedback Sweep

Scan open PRs for unresolved review feedback and dispatch agents to fix them.

## Setup

### Bootstrap Config

Check if the project-local config exists. If not, copy defaults from the plugin:

```bash
CONFIG_DIR=".claude/pr-feedback-sweep"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  PLUGIN_DEFAULTS="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")")")/defaults/config.yaml"
  if [ -f "$PLUGIN_DEFAULTS" ]; then
    cp "$PLUGIN_DEFAULTS" "$CONFIG_FILE"
  else
    # Inline fallback
    cat > "$CONFIG_FILE" <<'YAML'
max_prs: 30
skip_bots: false
bot_usernames:
  - "github-actions[bot]"
  - "copilot"
  - "dependabot[bot]"
  - "renovate[bot]"
  - "codecov[bot]"
  - "github-advanced-security[bot]"
YAML
  fi
fi
```

### Read Config Values

Resolve `yq` — try the binary first, fall back to Docker, warn if neither is available:

```bash
if command -v yq &>/dev/null; then
  YQ="yq"
elif command -v docker &>/dev/null; then
  YQ="docker run --rm -i mikefarah/yq"
else
  echo "WARNING: yq not found and Docker not available. Using defaults."
  YQ=""
fi

if [ -n "$YQ" ]; then
  MAX_PRS=$($YQ '.max_prs // 30' "$CONFIG_FILE")
  SKIP_BOTS=$($YQ '.skip_bots // false' "$CONFIG_FILE")
  BOT_USERNAMES=$($YQ '.bot_usernames // [] | .[]' "$CONFIG_FILE")
else
  MAX_PRS=30
  SKIP_BOTS=false
  BOT_USERNAMES="github-actions[bot] copilot dependabot[bot] renovate[bot] codecov[bot] github-advanced-security[bot]"
fi
```

### Detect Repository

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

All commands below use `$REPO` — this skill works with any GitHub repository.

## Workflow

### Determine Target PRs

The skill supports three targeting modes based on the arguments provided:

1. **No arguments** — auto-detect the PR for the current branch:
   ```bash
   CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
   PR_JSON=$(gh pr list --repo "$REPO" --head "$CURRENT_BRANCH" --state open --json number,title,headRefName --limit 1)
   ```
   - If a PR is found, sweep that single PR.
   - If no PR is found, ask the user: scan all open PRs (`--all` behavior) or exit.

2. **`--all`** — scan all open PRs up to `max_prs` from config:
   ```bash
   gh pr list --repo "$REPO" --state open --json number,title,headRefName --limit "$MAX_PRS"
   ```

3. **Explicit PR numbers** (e.g. `965 988`) — scan only those PRs. `max_prs` does not apply:
   ```bash
   # For each provided number:
   gh pr view {NUMBER} --repo "$REPO" --json number,title,headRefName
   ```
   - If both `--all` and explicit numbers are given, explicit numbers override `--all`.

### Phase 1: Discover Open PRs

Using the targeting mode determined above, build the list of PRs to sweep.

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

**Filter bot comments** when `skip_bots` is true. Read `bot_usernames` from config — the defaults ship with common bot accounts, and users can add or remove entries in their project-local config file.

Present a table organized by PR:

```markdown
## PR #XXX — Title (branch: branch-name)
| # | Source | User | File:Line | Feedback |
|---|--------|------|-----------|----------|
| 1 | review | reviewer | src/foo.ts:28 | Description of finding |
| 2 | comment | reviewer | — | Description of comment |
```

Also skip feedback that is:
- From the PR author acknowledging a comment (e.g., "fixed", "done", "addressed")
- Already resolved review threads

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
/pr-feedback-sweep             # Auto-detect PR for current branch
/pr-feedback-sweep --all       # Sweep all open PRs (up to max_prs)
/pr-feedback-sweep 965 988     # Sweep specific PRs only
```
