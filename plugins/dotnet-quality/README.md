# dotnet-quality

.NET development quality toolkit for Claude Code. Auto-formats C# on edit, enforces TDD workflow, and diagnoses CI failures.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install dotnet-quality@wonderforgelabs-plugins
```

## What It Does

### PostToolUse Hook (runs after editing)

| Hook | What | When |
|------|------|------|
| C# auto-format | Runs `dotnet format` on changed files | Any `.cs` file edit |

The formatting hook auto-discovers the nearest `.sln` or `.slnx` file (configurable depth) so it works with any .NET solution layout.

### Skills

| Skill | Trigger | What |
|-------|---------|------|
| `tdd-workflow` | Automatically applied during implementation tasks | Red-green-refactor for .NET, Jest, and Playwright |
| `diagnose-ci-failure` | `/diagnose-ci-failure [run-id]` | Fetches CI logs, categorizes failure, suggests fixes |

## Configuration

The formatting hook reads settings from a YAML config file at:

```
.claude/dotnet-quality/config.yaml
```

On the first hook run, if this file does not exist, it is auto-created from the plugin's built-in defaults:

```yaml
format:
  enabled: true
  sln_discovery_depth: 2
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `format.enabled` | bool | `true` | Enable or disable C# auto-formatting |
| `format.sln_discovery_depth` | int | `2` | Max directory depth below the project root to search for `.sln`/`.slnx` files |

To disable formatting, set `format.enabled` to `false` in your config file. To search deeper for solution files in nested project structures, increase `sln_discovery_depth`.

The config file is parsed using `yq`. If `yq` is not installed locally, the hook falls back to running it via Docker (`mikefarah/yq` image). If neither is available, the hook exits gracefully with a warning.

## Usage

### TDD Workflow

The TDD skill activates automatically when Claude is implementing features or fixing bugs. It guides the red-green-refactor cycle:

1. Write a failing test first
2. Implement until green
3. Refactor while keeping tests green

Supports .NET (xUnit/NUnit), Jest, and Playwright test frameworks.

### CI Failure Diagnosis

```
/diagnose-ci-failure
/diagnose-ci-failure 12345678
```

If no run-id is provided, it finds the latest failed run for the current branch. The skill:

1. Identifies which jobs failed
2. Categorizes the failure (build / test / E2E / quality / deployment)
3. Distinguishes transient vs persistent failures
4. Suggests a fix or retries transient issues

## Requirements

- .NET SDK with `dotnet format` support (.NET 6+)
- `jq` for parsing tool input JSON
- `yq` for reading YAML config (or Docker with `mikefarah/yq` image)
- GitHub CLI (`gh`) for CI diagnosis
- Node.js (optional, for Jest/Playwright TDD)

## Files

| File | Purpose |
|------|---------|
| `defaults/config.yaml` | Default configuration (copied on first run) |
| `hooks/hooks.json` | Hook definitions |
| `hooks/scripts/dotnet-format.sh` | C# auto-formatting script |
| `skills/tdd-workflow/SKILL.md` | TDD workflow for .NET, Jest, and Playwright |
| `skills/diagnose-ci-failure/SKILL.md` | CI failure investigation workflow |
| `commands/diagnose-ci-failure.md` | Slash command for `/diagnose-ci-failure` |
