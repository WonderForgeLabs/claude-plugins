# adr

Architecture Decision Record (ADR) and Domain Decision Record (DDR) generator with structured templates.

## Install

```bash
# Add the WonderForgeLabs marketplace (one-time)
claude plugin marketplace add WonderForgeLabs/claude-plugins

# Install the plugin
claude plugin install adr@wonderforgelabs-plugins
```

## Usage

Once installed, invoke the command in Claude Code:

```
/adr adr Add WebSocket support for real-time updates
/adr ddr Artifact versioning strategy
```

Or trigger it naturally by asking Claude to "create an ADR for...", "document this architecture decision", or "write a DDR for...".

## What It Does

1. Bootstraps configuration from `.claude/adr/config.yaml` (auto-created on first use with defaults)
2. Determines the next available number by scanning existing files in the configured ADR/DDR directories
3. Asks clarifying questions about the problem, constraints, and alternatives
4. Generates a properly formatted document using the appropriate template
5. Includes sections for status, context, decision, alternatives, consequences, and success metrics

## Configuration

On first use, the plugin creates a config file at `.claude/adr/config.yaml` with default values. You can customize it to match your project's conventions.

**Config file location:** `$CLAUDE_PROJECT_DIR/.claude/adr/config.yaml`

**Default values:**

```yaml
adr_directory: "docs/adr"
ddr_directory: "docs/ddr"
numbering_format: "%04d"
```

| Key | Description | Default |
|-----|-------------|---------|
| `adr_directory` | Directory for Architecture Decision Records | `docs/adr` |
| `ddr_directory` | Directory for Domain Decision Records | `docs/ddr` |
| `numbering_format` | printf-style format string for record numbers (e.g. `%04d` produces `0001`) | `%04d` |

Config values are read using `yq`. If `yq` is not available, the plugin falls back to Docker (`docker run --rm -i mikefarah/yq`). If neither is available, the plugin warns the user and uses the defaults above.

## Record Types

| Type | Focus | Directory |
|------|-------|-----------|
| ADR | Technical architecture (infrastructure, APIs, data flow) | Configured via `adr_directory` |
| DDR | Domain design (user experience, entity modeling, workflows) | Configured via `ddr_directory` |

## Features

- Auto-numbering based on existing records (configurable format)
- Structured templates with all standard sections
- Mermaid diagram support for architecture visualizations
- Cross-referencing between related ADRs/DDRs
- Concrete success metrics prompts

## Requirements

- Claude Code with plugin support
- `yq` (optional) — used to read config values; install via your package manager or use Docker with the `mikefarah/yq` image as a fallback

## Files

| File | Purpose |
|------|---------|
| `skills/adr/SKILL.md` | Skill definition with templates and workflow |
| `commands/adr.md` | Slash command definition |
| `defaults/config.yaml` | Default configuration values |
