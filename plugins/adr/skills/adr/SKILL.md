---
name: adr
description: Create Architecture Decision Record (ADR) or Domain Decision Record (DDR) following project conventions. Use when documenting significant technical or design decisions.
---

# ADR/DDR Generator

Create properly formatted Architecture Decision Records (ADRs) or Domain Decision Records (DDRs) following project conventions.

## Usage

```
/adr <type> <title>
```

- `type`: Either `adr` (technical/architecture) or `ddr` (domain/user experience)
- `title`: Brief description of the decision

## Examples

```
/adr adr Add WebSocket support for real-time updates
/adr ddr Artifact versioning strategy
```

## Configuration Bootstrap

Before doing any work, load configuration values:

1. **Check for project config:**
   ```bash
   CONFIG_FILE="$CLAUDE_PROJECT_DIR/.claude/adr/config.yaml"
   ```

2. **If the config file does not exist, create it from plugin defaults:**
   ```bash
   mkdir -p "$CLAUDE_PROJECT_DIR/.claude/adr"
   cp "$(dirname "$0")/../../defaults/config.yaml" "$CONFIG_FILE"
   ```
   If the copy source is unavailable, create the file with these defaults:
   ```yaml
   adr_directory: "docs/adr"
   ddr_directory: "docs/ddr"
   numbering_format: "%04d"
   ```

3. **Read config values using yq:**
   ```bash
   ADR_DIR=$(yq '.adr_directory' "$CONFIG_FILE")
   DDR_DIR=$(yq '.ddr_directory' "$CONFIG_FILE")
   NUMBERING_FORMAT=$(yq '.numbering_format' "$CONFIG_FILE")
   ```

   If `yq` is not in PATH, try `docker run --rm -i mikefarah/yq`. If neither is available, warn the user and use defaults (`docs/adr`, `docs/ddr`, `%04d`).

4. **Use these values throughout the workflow.** All directory references and number formatting below use the config-driven values.

## Workflow

1. **Determine next number**: Check existing files in `$ADR_DIR` or `$DDR_DIR` (from config). Format the number using `$NUMBERING_FORMAT` (e.g., `printf "$NUMBERING_FORMAT" $NEXT_NUM`).
2. **Gather context**: Ask clarifying questions about:
   - What problem are we solving?
   - What constraints exist?
   - What alternatives were considered?
3. **Generate the document** using the appropriate template

## ADR Template ($ADR_DIR/)

For technical/architecture decisions:

```markdown
# ADR-XXX: [Title]

## Status

Proposed

## Context

[Problem statement, constraints, assumptions]

## Decision

[What we decided, with architecture diagram if applicable]

## Alternatives Considered

### Alternative 1: [Name]
- **Pros:** ...
- **Cons:** ...
- **Decision:** Rejected - [reason]

## Implementation Guidelines

[Development and deployment considerations]

## Consequences

### Positive Consequences
- ...

### Negative Consequences
- ...

## Success Metrics

- ...

## Related ADRs

- ADR-XXX: [Related decision]

## References

- [Links to relevant documentation]

---
**Date:** YYYY-MM-DD
**Authors:** Development Team
**Reviewers:** Architecture Team
**Next Review:** YYYY-MM-DD (6 months)
```

## DDR Template ($DDR_DIR/)

For domain/user experience decisions:

```markdown
# DDR-XXX: [Title]

## Status

Proposed

## Context

[What design challenge or user experience problem are we addressing?]

## Decision

[What design approach, pattern, or user experience solution did we choose?]

## Rationale

[Why does this design choice better serve our users and align with the project's goals?]

## Consequences

**Positive:**
- ...

**Negative:**
- ...

**Implementation Impact:**
- ...

## Alternatives Considered

1. **[Option]**: Rejected - [reason]

## Notes

[Additional context, references, or future considerations]
```

## Key Principles

- ADRs: Focus on **technical architecture** (infrastructure, APIs, data flow)
- DDRs: Focus on **domain design** (user experience, entity modeling, workflows)
- Use mermaid diagrams for architecture visualizations
- Link related ADRs/DDRs for traceability
- Include concrete success metrics where possible
