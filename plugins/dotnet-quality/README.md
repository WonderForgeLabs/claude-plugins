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

The formatting hook auto-discovers the nearest `.sln` or `.slnx` file (up to 2 levels below the project root) so it works with any .NET solution layout.

### Skills

| Skill | Trigger | What |
|-------|---------|------|
| `tdd-workflow` | Automatically applied during implementation tasks | Red-green-refactor for .NET, Jest, and Playwright |
| `diagnose-ci-failure` | `/diagnose-ci-failure [run-id]` | Fetches CI logs, categorizes failure, suggests fixes |

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
- GitHub CLI (`gh`) for CI diagnosis
- Node.js (optional, for Jest/Playwright TDD)

## Files

| File | Purpose |
|------|---------|
| `skills/tdd-workflow/SKILL.md` | TDD workflow for .NET, Jest, and Playwright |
| `skills/diagnose-ci-failure/SKILL.md` | CI failure investigation workflow |
| `commands/diagnose-ci-failure.md` | Slash command for `/diagnose-ci-failure` |
