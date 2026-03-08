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

1. Determines the next available number by scanning existing files in `docs/ADR/` or `docs/DDR/`
2. Asks clarifying questions about the problem, constraints, and alternatives
3. Generates a properly formatted document using the appropriate template
4. Includes sections for status, context, decision, alternatives, consequences, and success metrics

## Record Types

| Type | Focus | Directory |
|------|-------|-----------|
| ADR | Technical architecture (infrastructure, APIs, data flow) | `docs/ADR/` |
| DDR | Domain design (user experience, entity modeling, workflows) | `docs/DDR/` |

## Features

- Auto-numbering based on existing records
- Structured templates with all standard sections
- Mermaid diagram support for architecture visualizations
- Cross-referencing between related ADRs/DDRs
- Concrete success metrics prompts

## Files

| File | Purpose |
|------|---------|
| `skills/adr/SKILL.md` | Skill definition with templates and workflow |
| `commands/adr.md` | Slash command definition |
