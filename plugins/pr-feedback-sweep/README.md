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
/pr-feedback-sweep             # Auto-detect PR for current branch
/pr-feedback-sweep --all       # Sweep all open PRs (up to max_prs)
/pr-feedback-sweep 965 988     # Sweep specific PRs only
```

- **No arguments**: detects the PR for your current branch. If no PR is found, asks whether to scan all open PRs or exit.
- **`--all`**: scans all open PRs up to the `max_prs` config limit.
- **Explicit PR numbers**: scans only the listed PRs. `max_prs` does not apply. If both `--all` and explicit numbers are given, explicit numbers take precedence.

Or trigger it naturally by asking Claude to "check PRs for feedback", "sweep PR reviews", or "find unresolved PR comments".

## Configuration

The plugin reads settings from `.claude/pr-feedback-sweep/config.yaml` in your project root. This file is auto-created on first use with default values:

```yaml
max_prs: 30
skip_bots: true
bot_usernames: []
```

| Setting | Default | Description |
|---------|---------|-------------|
| `max_prs` | `30` | Maximum number of open PRs to scan in `--all` mode |
| `skip_bots` | `true` | Filter out comments from known bot usernames |
| `bot_usernames` | `[]` | Additional bot usernames to filter, merged with the hardcoded list (`github-actions[bot]`, `copilot`, `dependabot[bot]`, `renovate[bot]`, `codecov[bot]`, `github-advanced-security[bot]`) |

Config values are read via `yq`. If `yq` is not installed, the plugin falls back to Docker (`mikefarah/yq` image). If neither is available, built-in defaults are used with a warning.

## What It Does

1. Detects the current GitHub repository automatically
2. Lists open PRs based on the targeting mode selected
3. Fetches all feedback sources: issue comments, review comments, and reviews
4. Filters out resolved threads, bot comments, and author acknowledgements
5. Compiles a summary table organized by PR
6. Offers to dispatch fix agents for each PR with unresolved feedback
7. Sets up worktrees and installs dependencies for each agent

## Requirements

- GitHub CLI (`gh`) authenticated
- Git
- `yq` (or Docker with `mikefarah/yq` image) for reading config
- GitHub MCP server plugin (optional -- used as fallback when GitHub API rate limit is hit)

## Rate Limit Handling

If the GitHub API rate limit is hit, the skill falls back to MCP GitHub tools which use a separate rate limit pool. If both are limited, it reports the situation and suggests retrying later.

## Files

| File | Purpose |
|------|---------|
| `skills/pr-feedback-sweep/SKILL.md` | Skill definition with full workflow |
| `commands/pr-feedback-sweep.md` | Slash command definition |
| `defaults/config.yaml` | Default configuration values |
