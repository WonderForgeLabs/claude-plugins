# aspire-bisect

Bisect .NET Aspire NuGet daily builds to pinpoint regressions. Uses git worktrees for isolation, adaptive sampling (3 samples per round), and DCP log collection.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install aspire-bisect@wonderforgelabs
```

## Usage

Once installed, invoke the skill in Claude Code:

```
/aspire-bisect
```

Or trigger it naturally by asking Claude to "bisect aspire versions", "find aspire regression", or "which aspire version broke".

## What It Does

1. Sets up a minimal standalone repro repo with an AppHost and xUnit test
2. Fetches all available Aspire package versions from the NuGet feed
3. Establishes known-good and known-bad version bounds
4. Bisects using adaptive sampling (3 versions per round) with git worktrees
5. Collects DCP logs and test output as evidence
6. Reports the exact version pair where the regression was introduced

## Requirements

- .NET 10 SDK
- Docker (for Aspire DCP containers)
- Python 3 (for JSON parsing in the bisect script)
- Git

## Version Format

Aspire daily builds follow `major.minor.patch-preview.1.YMMDD.build` -- the date component (`YMMDD`) maps to commits in the [dotnet/aspire](https://github.com/dotnet/aspire) repo.

## Files

| File | Purpose |
|------|---------|
| `skills/aspire-bisect/SKILL.md` | Skill definition with full workflow |
| `skills/aspire-bisect/scripts/bisect.sh` | Bisect script to copy into repro repos |
| `skills/aspire-bisect/references/test-template.md` | Complete xUnit test template |
| `skills/aspire-bisect/references/known-results.md` | Previously bisected regressions |
