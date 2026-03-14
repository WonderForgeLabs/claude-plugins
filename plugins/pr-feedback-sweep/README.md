# pr-feedback-sweep

Scan open PRs for unresolved review feedback and dispatch fix agents. Works with any GitHub repository -- detects the repo dynamically from the current working directory.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install pr-feedback-sweep@wonderforgelabs-plugins
```

## Usage

Once installed, invoke the skill in Claude Code:

```
/pr-feedback-sweep           # Full sweep of all open PRs
/pr-feedback-sweep 965 988   # Sweep specific PRs only
```

Or trigger it naturally by asking Claude to "check PRs for feedback", "sweep PR reviews", or "find unresolved PR comments".

## What It Does

1. Detects the current GitHub repository automatically
2. Lists all open PRs (or specific ones if numbers are provided)
3. Fetches all feedback sources: issue comments, review comments, and reviews
4. Filters out resolved threads, bot comments, and author acknowledgements
5. Compiles a summary table organized by PR
6. Offers to dispatch fix agents for each PR with unresolved feedback
7. Sets up worktrees and installs dependencies for each agent

## Requirements

- GitHub CLI (`gh`) authenticated
- Git
- GitHub MCP server plugin (optional -- used as fallback when GitHub API rate limit is hit)

## Rate Limit Handling

If the GitHub API rate limit is hit, the skill falls back to MCP GitHub tools which use a separate rate limit pool. If both are limited, it reports the situation and suggests retrying later.

## Files

| File | Purpose |
|------|---------|
| `skills/pr-feedback-sweep/SKILL.md` | Skill definition with full workflow |
| `commands/pr-feedback-sweep.md` | Slash command definition |
